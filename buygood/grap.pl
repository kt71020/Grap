#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

# 確保 UTF-8 輸出
binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";

use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Request::Common qw(GET POST);
use HTML::TreeBuilder::XPath;
use URI::Escape qw(uri_escape_utf8);
use Encode      qw(decode encode_utf8);

# 城市列表（根據 grap.md 中的 HTML select 選項）
my @cities = (
    "基隆市", "台北市", "新北市", "桃園市", "新竹市", "新竹縣", "苗栗縣", "台中市", "彰化縣", "南投縣",
    "雲林縣", "嘉義市", "嘉義縣", "台南市", "高雄市", "屏東縣", "宜蘭縣", "台東縣", "花蓮縣", "金門縣"
);

# 測試用：只抓取部分城市
# @cities = ( "台北市", "台中市" );

# Initialize HTTP client
my $ua = LWP::UserAgent->new(
    agent =>
'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    cookie_jar => HTTP::Cookies->new,
    timeout    => 30,
);
$ua->requests_redirectable( [ 'GET', 'HEAD', 'POST' ] );

# Constants
my $BASE_URL = 'https://www.buygood.com.tw/StoreList.asp';

# 建立輸出目錄
my $csv_dir = 'csv';
mkdir $csv_dir unless -d $csv_dir;

print "開始爬取梁社漢排骨門市資訊...\n";
print "目標網站：$BASE_URL\n";
print "=" x 60 . "\n";

my $total_all_stores = 0;

# 遍歷每個城市
for my $city (@cities) {
    print "處理城市：$city...\n";

    # 準備 CSV 檔案（使用城市名稱作為檔案名）
    my $safe_city = $city;
    $safe_city =~ s/[^\w\-]/_/g;    # 處理檔案名稱中的特殊字符

    my $csv_file = "$csv_dir/$safe_city.csv";
    open my $fh_csv, '>:encoding(UTF-8)', $csv_file or die "無法開啟 $csv_file: $!";
    print $fh_csv "name,phone,city,region,detailed_address,latitude,longitude\n";

    my $total_stores = 0;

    # 發送 POST 請求查詢該城市的門市
    my $form_data = [
        't'          => '4',
        'cityselect' => $city,
        'SArea'      => $city . '全區'
    ];

    my $res = $ua->post( $BASE_URL, $form_data );

    if ( !$res->is_success ) {
        warn "查詢 $city 失敗: " . $res->status_line;
        close $fh_csv;
        next;
    }

    my $html = decode( 'utf8', $res->content );

    # 解析 HTML
    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse($html);
    $tree->eof;

    # 修正選擇器：直接找所有包含店名的 h4 標籤
    my @store_headers = $tree->findnodes('//h4//font[@color="#D9534F"]');

    print "  找到 " . scalar(@store_headers) . " 個門市\n";

    foreach my $store_header (@store_headers) {

        # 提取店名
        my $store_name = trim( $store_header->as_text );
        $store_name =~ s/\[.*?\]//g;    # 移除 [線上訂餐] 等標記

        # 🔧 修正邏輯：從店名節點找後續的電話和地址節點
        # 先找到 h4 父節點
        my $h4_node = $store_header;
        while ( $h4_node && $h4_node->tag ne 'h4' ) {
            $h4_node = $h4_node->parent;
        }

        next unless $h4_node;

        # 從 h4 節點開始找後續的兄弟節點中的電話和地址
        my $phone   = '';
        my $address = '';

        # 找 h4 後面的所有兄弟節點
        my $current      = $h4_node->right;
        my $max_search   = 10;                # 限制搜尋範圍，避免找到其他店的資料
        my $search_count = 0;

        while ( $current && $search_count < $max_search ) {
            $search_count++;

            # 如果遇到下一個 h4，就停止搜尋
            if ( $current->tag && $current->tag eq 'h4' ) {
                last;
            }

            # 如果遇到 hr，也停止搜尋（每個店用 hr 分隔）
            if ( $current->tag && $current->tag eq 'hr' ) {
                last;
            }

            # 找電話：包含 tel: 的 a 標籤
            if ( !$phone ) {
                my @phone_links = $current->findnodes('.//a[starts-with(@href, "tel:")]');
                if ( @phone_links > 0 ) {
                    $phone = trim( $phone_links[0]->as_text );
                }
            }

            # 找地址：包含「台灣」的 p 標籤
            if ( !$address ) {
                if ( $current->tag && $current->tag eq 'p' ) {
                    my $text = trim( $current->as_text );
                    if ( $text =~ /台灣/ ) {
                        $address = $text;
                        $address =~ s/台灣\s*//;    # 移除 "台灣" 前綴
                    }
                }
            }

            # 如果都找到了，就可以停止
            if ( $phone && $address ) {
                last;
            }

            $current = $current->right;
        }

        # 如果沒找到電話或地址，跳過這個店
        next if !$store_name || !$address;

        # 處理店名格式
        my $formatted_name = "梁社漢排骨 $store_name";

        # 處理電話格式
        my $formatted_phone = format_phone($phone);

        # 解析地址取得地區資訊
        my ( $region, $detailed_address ) = parse_address( $address, $city );

        # 由於網站沒有提供經緯度，使用空值
        my $latitude  = '';
        my $longitude = '';

        # 寫入 CSV
        my $csv_line = join( ',',
            quote_csv($formatted_name),
            quote_csv($formatted_phone),
            quote_csv($city), quote_csv($region), quote_csv($detailed_address),
            $latitude,        $longitude );

        print $fh_csv $csv_line . "\n";
        $total_stores++;

        print "    $formatted_name - $formatted_phone - $detailed_address\n";
    }

    $tree->delete;
    close $fh_csv;

    print "  $city 完成，共抓取 $total_stores 個門市，儲存至 $csv_file\n";
    $total_all_stores += $total_stores;

    # 城市間的延遲避免被封鎖
    sleep 5;
}

print "\n" . "=" x 60 . "\n";
print "梁社漢排骨門市資訊爬取完成！\n";
print "總共抓取 $total_all_stores 個門市\n";

# 輔助函數：清理文字
sub trim {
    my $text = shift;
    return '' unless defined $text;
    $text =~ s/^\s+|\s+$//g;
    $text =~ s/\s+/ /g;        # 將多個空白字符合併為一個
    return $text;
}

# 輔助函數：格式化電話號碼
sub format_phone {
    my $phone = shift;
    return '' unless $phone;

    # 移除所有非數字字符
    ( my $digits = $phone ) =~ s/\D//g;

    # 台灣電話號碼格式化
    if ( $digits =~ /^(\d{2})(\d{4})(\d{4})$/ ) {
        return "$1-$2-$3";    # 10位數：XX-XXXX-XXXX
    }
    elsif ( $digits =~ /^(\d{2})(\d{7})$/ ) {
        return "$1-$2";       # 9位數：XX-XXXXXXX
    }
    elsif ( $digits =~ /^(\d{3})(\d{3})(\d{4})$/ ) {
        return "$1-$2-$3";    # 手機：XXX-XXX-XXXX
    }

    return $phone;            # 如果格式不符合，返回原始電話號碼
}

# 輔助函數：解析地址
sub parse_address {
    my ( $address, $city ) = @_;

    # 移除城市名稱前綴
    $address =~ s/^\Q$city\E//;

    # 嘗試提取地區資訊（區、鄉、鎮等）
    my $region = '';
    if ( $address =~ /^([^\d]*?[區鄉鎮市])(.*)$/ ) {
        $region  = $1;
        $address = $2;
    }

    return ( trim($region), trim($address) );
}

# 輔助函數：CSV 欄位引號處理
sub quote_csv {
    my $field = shift;
    return '' unless defined $field;

    # 如果包含逗號、引號或換行符，需要用引號包圍
    if ( $field =~ /[,"\n\r]/ ) {
        $field =~ s/"/""/g;    # 雙引號轉義
        $field = "\"$field\"";
    }

    return $field;
}
