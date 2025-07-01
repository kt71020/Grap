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
use JSON;

# 城市代碼對照表 (code => name)
my %city_map = (
    '7'  => '台北市',
    '8'  => '基隆市',
    '9'  => '新北市',
    '11' => '宜蘭縣',
    '13' => '新竹縣',
    '14' => '桃園市',
    '15' => '苗栗縣',
    '16' => '台中市',
    '17' => '彰化縣',
    '18' => '南投縣',
    '19' => '嘉義市',
    '20' => '嘉義縣',
    '21' => '雲林縣',
    '22' => '台南市',
    '23' => '高雄市',
    '24' => '澎湖縣',
    '25' => '金門縣',
    '26' => '屏東縣',
    '27' => '台東縣',
    '28' => '花蓮縣',
);

# 測試用：只抓取部分城市
# %city_map = ( '7' => '台北市', '16' => '台中市' );

# Initialize HTTP client
my $ua = LWP::UserAgent->new(
    agent      => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    cookie_jar => HTTP::Cookies->new,
    timeout    => 30,
);
$ua->requests_redirectable( [ 'GET', 'HEAD' ] );

# Constants
my $BASE_URL = 'https://www.wu-tau.com/store.php';

# 建立輸出目錄
my $csv_dir = 'csv';
mkdir $csv_dir unless -d $csv_dir;

print "開始爬取悟饕池上飯包門市資訊...\n";

# 遍歷每個城市代碼與名稱
for my $CITY_CODE ( sort { $a <=> $b } keys %city_map ) {
    my $CITY_NAME = $city_map{$CITY_CODE};
    print "處理城市 $CITY_CODE: $CITY_NAME...\n";

    # 準備 CSV 檔案
    my $csv_file = "$csv_dir/$CITY_CODE.csv";
    open my $fh_csv, '>:encoding(UTF-8)', $csv_file or die "無法開啟 $csv_file: $!";
    print $fh_csv "name,phone,city,region,detailed_address,latitude,longitude\n";

    my $page         = 1;
    my $total_stores = 0;

    while (1) {
        print "  抓取第 $page 頁...\n";

        # 發送查詢請求
        my $url = $BASE_URL . "?act=query&city_id=" . uri_escape_utf8($CITY_CODE);
        if ( $page > 1 ) {
            $url .= "&page=$page";
        }

        my $res = $ua->get($url);
        if ( !$res->is_success ) {
            warn "GET $url 失敗: " . $res->status_line;
            last;
        }

        my $html = decode( 'utf8', $res->content );

        # 解析 HTML
        my $tree = HTML::TreeBuilder::XPath->new;
        $tree->parse($html);
        $tree->eof;

        # 抓取門市資料表格 (修正 class 選擇器)
        my @rows = $tree->findnodes('//tbody/tr');

        if ( @rows == 0 ) {
            print "  第 $page 頁沒有找到門市資料，結束抓取\n";
            last;
        }

        foreach my $row (@rows) {
            my @cells = $row->findnodes('./td');
            next if @cells < 5;

            my $city       = trim( $cells[0]->as_text );
            my $region     = trim( $cells[1]->as_text );
            my $store_name = trim( $cells[2]->as_text );
            my $phone      = trim( $cells[3]->as_text );
            my $address    = trim( $cells[4]->as_text );

            # 跳過不是當前城市的資料
            next if $city ne $CITY_NAME;

            # 處理店名
            my $formatted_name = "悟饕池上飯包 $store_name";

            # 處理電話格式
            my $formatted_phone = format_phone($phone);

            # 處理地址（移除城市和地區前綴）
            my $detailed_address = $address;
            $detailed_address =~ s/^\Q$city$region\E//;
            $detailed_address =~ s/^\Q$city\E//;
            $detailed_address =~ s/^\Q$region\E//;

            # 由於這個網站沒有提供經緯度，我們暫時用空值
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

        # 檢查是否有下一頁
        my $tree2 = HTML::TreeBuilder::XPath->new;
        $tree2->parse($html);
        $tree2->eof;

        my @next_links = $tree2->findnodes('//div[@class="p-pager"]//a[@class="next " and @title="Next Page"]');
        if ( @next_links == 0 ) {
            print "  沒有下一頁，結束抓取\n";
            $tree2->delete;
            last;
        }

        $tree2->delete;
        $page++;

        # 延遲避免被封鎖
        sleep 2;
    }

    close $fh_csv;
    print "  $CITY_NAME 完成，共抓取 $total_stores 個門市，儲存至 $csv_file\n";

    # 城市間的延遲
    sleep 3;
}

print "悟饕池上飯包門市資訊爬取完成！\n";

# 輔助函數：清理文字
sub trim {
    my $text = shift;
    $text =~ s/^\s+|\s+$//g;
    return $text;
}

# 輔助函數：格式化電話號碼
sub format_phone {
    my $phone = shift;
    return $phone unless $phone;

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
    else {
        return $phone;        # 其他格式保持原樣
    }
}

# 輔助函數：CSV 欄位引號處理
sub quote_csv {
    my $text = shift;
    return '' unless defined $text;

    # 如果包含逗號、引號或換行，則加上引號
    if ( $text =~ /[,"\n]/ ) {
        $text =~ s/"/""/g;    # 雙引號轉義
        return "\"$text\"";
    }

    return $text;
}

__END__
