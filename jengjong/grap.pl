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

# 初始化 HTTP 客戶端
my $ua = LWP::UserAgent->new(
    agent =>
'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    cookie_jar => HTTP::Cookies->new,
    timeout    => 30,
);
$ua->requests_redirectable( [ 'GET', 'HEAD', 'POST' ] );

# 常數設定
my $BASE_URL = 'http://www.jengjong.tw/mobile/branch.php';

# 建立輸出目錄
my $csv_dir = 'csv';
mkdir $csv_dir unless -d $csv_dir;

print "開始爬取正忠排骨飯門市資訊...\n";
print "目標網站：$BASE_URL\n";
print "=" x 60 . "\n";

# 先取得主頁面，分析城市資訊
print "正在取得門市列表頁面...\n";

my $res = $ua->get($BASE_URL);

if ( !$res->is_success ) {
    die "無法存取目標網站: " . $res->status_line;
}

my $html = decode( 'utf8', $res->content );

# 解析 HTML
my $tree = HTML::TreeBuilder::XPath->new;
$tree->parse($html);
$tree->eof;

# 找到所有的 branch_list 區塊
my @branch_blocks = $tree->findnodes('//div[@class="branch_list"]');

print "找到 " . scalar(@branch_blocks) . " 個門市資訊\n";

my %city_stores  = ();    # 用來按城市分類門市資料
my $total_stores = 0;

foreach my $branch (@branch_blocks) {

    # 解析門市名稱（從 title div 中提取）
    my @title_nodes = $branch->findnodes('.//div[@class="title"]');
    next unless @title_nodes;

    my $title_text = trim( $title_nodes[0]->as_text );
    next unless $title_text;

    # 從標題中解析城市和店名
    # 格式：[高雄市]正忠店
    my ( $city, $store_name );
    if ( $title_text =~ /^\[([^\]]+)\](.+)$/ ) {
        $city       = $1;
        $store_name = $2;
    }
    else {
        # 如果格式不符，嘗試其他解析方式
        warn "無法解析門市標題格式: $title_text";
        next;
    }

    # 解析 infobox 中的詳細資訊
    my @infobox_nodes = $branch->findnodes('.//div[@class="infobox"]');
    next unless @infobox_nodes;

    my $phone   = '';
    my $address = '';
    my $fax     = '';
    my $hours   = '';

    # 找到所有的 list div
    my @list_nodes = $infobox_nodes[0]->findnodes('.//div[@class="list"]');

    foreach my $list_node (@list_nodes) {
        my @left_nodes  = $list_node->findnodes('.//div[@class="left"]');
        my @right_nodes = $list_node->findnodes('.//div[@class="right"]');

        next unless @left_nodes && @right_nodes;

        my $label = trim( $left_nodes[0]->as_text );
        my $value = trim( $right_nodes[0]->as_text );

        if ( $label =~ /訂購專線/ ) {
            $phone = $value;
        }
        elsif ( $label =~ /傳真電話/ ) {
            $fax = $value;
        }
        elsif ( $label =~ /地.*址/ ) {

            # 如果 right div 中有 a 標籤，取 a 標籤的文字
            my @addr_links = $right_nodes[0]->findnodes('.//a');
            if (@addr_links) {
                $address = trim( $addr_links[0]->as_text );
            }
            else {
                $address = $value;
            }
        }
        elsif ( $label =~ /營業時間/ ) {
            $hours = $value;
        }
    }

    # 跳過沒有基本資訊的門市
    next unless $store_name && $phone && $address;

    # 處理店名格式
    my $formatted_name = "正忠排骨飯 $store_name";

    # 處理電話格式
    my $formatted_phone = format_phone($phone);

    # 解析地址取得地區資訊
    my ( $region, $detailed_address ) = parse_address( $address, $city );

    # 由於網站沒有提供經緯度，使用空值
    my $latitude  = '';
    my $longitude = '';

    # 將資料按城市分類
    $city_stores{$city} ||= [];
    push @{ $city_stores{$city} },
      {
        name             => $formatted_name,
        phone            => $formatted_phone,
        city             => $city,
        region           => $region,
        detailed_address => $detailed_address,
        latitude         => $latitude,
        longitude        => $longitude,
        fax              => $fax,
        hours            => $hours
      };

    $total_stores++;
    print "    $formatted_name - $formatted_phone - $detailed_address\n";
}

$tree->delete;

# 輸出各城市的 CSV 檔案
foreach my $city ( sort keys %city_stores ) {
    my $safe_city = $city;
    $safe_city =~ s/[^\w\-]/_/g;    # 處理檔案名稱中的特殊字符

    my $csv_file = "$csv_dir/$safe_city.csv";
    open my $fh_csv, '>:encoding(UTF-8)', $csv_file or die "無法開啟 $csv_file: $!";
    print $fh_csv "name,phone,city,region,detailed_address,latitude,longitude\n";

    my $city_count = 0;
    foreach my $store ( @{ $city_stores{$city} } ) {
        my $csv_line = join( ',',
            quote_csv( $store->{name} ),
            quote_csv( $store->{phone} ),
            quote_csv( $store->{city} ),
            quote_csv( $store->{region} ),
            quote_csv( $store->{detailed_address} ),
            $store->{latitude}, $store->{longitude} );

        print $fh_csv $csv_line . "\n";
        $city_count++;
    }

    close $fh_csv;
    print "  $city 完成，共 $city_count 個門市，儲存至 $csv_file\n";
}

print "\n" . "=" x 60 . "\n";
print "正忠排骨飯門市資訊爬取完成！\n";
print "總共抓取 $total_stores 個門市\n";
print "涵蓋 " . scalar( keys %city_stores ) . " 個城市\n";

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

    # 移除地址前面的郵遞區號（3位數字）
    $address =~ s/^\d{3}//;

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
