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
use Encode      qw(decode);
use JSON;
use Time::HiRes qw(sleep);

# 目標城市與輸出
my $CITY_NAME    = '台北市';
my $CSV_DIR      = 'csv';
my $CSV_FILENAME = 'OKmark';

# 城市代碼對照表 (code => name)
my %city_map = (
    '02' => '基隆市',
    '01' => '台北市',
    '03' => '新北市',
    '04' => '桃園市',
    '05' => '新竹市',
    '06' => '新竹縣',
    '07' => '苗栗縣',
    '08' => '台中市',
    '10' => '彰化縣',
    '11' => '南投縣',
    '12' => '雲林縣',
    '14' => '嘉義縣',
    '13' => '嘉義市',
    '15' => '台南市',
    '17' => '高雄市',
    '19' => '屏東縣',
    '20' => '宜蘭縣',
    '21' => '花蓮縣',
    '22' => '台東縣',
    '24' => '連江縣',
    '25' => '金門縣',
    '23' => '澎湖縣',
);

# 測試時只爬台北市
# %city_map = ( '01' => '台北市' );

mkdir $CSV_DIR unless -d $CSV_DIR;

# Initialize HTTP client
my $ua = LWP::UserAgent->new(
    agent =>
'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
    cookie_jar => HTTP::Cookies->new,
    timeout    => 30,
);
$ua->requests_redirectable( [ 'GET', 'HEAD' ] );

# Constants
my $BASE_URL        = 'https://www.okmart.com.tw';
my $ZIPCODE_URL     = "$BASE_URL/GetZipCode";
my $SHOP_SEARCH_URL = "$BASE_URL/convenient_shopSearch_Result.aspx";
my $SHOP_DETAIL_URL = "$BASE_URL/convenient_shopSearch_ShopResult.aspx";

# 遍歷每個城市
for my $city_code ( sort keys %city_map ) {
    my $city_name = $city_map{$city_code};
    print "Processing city: $city_name\n";

    # Step 1: 先訪問首頁獲取 Session
    my $main_page = $ua->get("$BASE_URL/convenient_shopSearch");
    unless ( $main_page->is_success ) {
        warn "Failed to get main page for $city_name: " . $main_page->status_line;
        next;
    }

    # Step 2: 取得該城市的鄉鎮市區列表
    my $zipcode_url = $ZIPCODE_URL . "?city=" . uri_escape_utf8($city_name) . "&ajax=true";
    my $res         = $ua->get(
        $zipcode_url,
        'Accept'           => 'application/json, text/javascript, */*; q=0.01',
        'X-Requested-With' => 'XMLHttpRequest',
        'Referer'          => "$BASE_URL/convenient_shopSearch"
    );

    unless ( $res->is_success ) {
        warn "Failed to get zipcode for $city_name: " . $res->status_line;
        next;
    }

    my $raw_content = $res->content;
    print "Raw response: " . substr( $raw_content, 0, 200 ) . "...\n";

    # 直接解析 UTF-8 JSON，不要再次 decode
    my $areas;
    eval { $areas = decode_json($raw_content); };

    if ( $@ || !$areas || ref($areas) ne 'ARRAY' ) {
        warn "Failed to parse JSON for $city_name: $@";
        print "Content type: " . ( $res->header('Content-Type') || 'unknown' ) . "\n";
        print "Content length: " . length($raw_content) . "\n";
        print "First 500 chars: " . substr( $raw_content, 0, 500 ) . "\n";
        next;
    }

    # 準備 CSV 檔案
    my $csv_file = "$CSV_DIR/$city_code.csv";
    open my $fh_csv, '>:encoding(UTF-8)', $csv_file or die "Cannot open $csv_file: $!";

    # CSV 標頭
    # print $fh_csv "name,phone,city,region,detailed_address,latitude,longitude\n";

    # Step 2: 遍歷每個區域
    for my $area_data (@$areas) {
        my $area = $area_data->{Area};
        print "  Processing area: $area\n";

        # 取得該區域的商店列表
        my $timestamp = time() . "000";    # 毫秒時間戳
        my $search_url =
            $SHOP_SEARCH_URL
          . "?city="
          . uri_escape_utf8($city_name)
          . "&zipcode="
          . uri_escape_utf8($area)
          . "&key=&service=&service2=&_=$timestamp";

        $res = $ua->get($search_url);

        unless ( $res->is_success ) {
            warn "Failed to get shops for $city_name $area: " . $res->status_line;
            next;
        }

        my $html_content = decode( 'utf8', $res->content );

        # 解析商店ID和基本資訊
        my @shop_ids;
        while ( $html_content =~ m/javascript:showshop\('(\d+)'/g ) {
            push @shop_ids, $1;
        }

        print "    Found " . scalar(@shop_ids) . " shops\n";

        # Step 3: 取得每個商店的詳細資訊
        for my $shop_id (@shop_ids) {
            my $detail_timestamp = time() . "000";
            my $detail_url       = $SHOP_DETAIL_URL . "?id=$shop_id&_=$detail_timestamp";

            $res = $ua->get($detail_url);

            unless ( $res->is_success ) {
                warn "Failed to get detail for shop $shop_id: " . $res->status_line;
                next;
            }

            my $detail_html = decode( 'utf8', $res->content );

            # 解析商店詳細資訊
            my ( $name, $address, $phone, $hours ) = ( '', '', '', '' );

            # 解析店名
            if ( $detail_html =~ m/<h1[^>]*>([^<]+)</ ) {
                $name = $1;
                $name =~ s/\s+/ /g;
                $name =~ s/^\s+|\s+$//g;
            }

            # 解析地址
            if ( $detail_html =~ m/門市地址：<\/span>([^<]+)</ ) {
                $address = $1;
                $address =~ s/^\s+|\s+$//g;
            }

            # 解析電話
            if ( $detail_html =~ m/門市電話：<\/span>([^<]+)</ ) {
                $phone = $1;
                $phone =~ s/^\s+|\s+$//g;
            }

            # 處理資料
            if ( $name && $address && $phone ) {

                # 前加 Okmart 前綴
                $name = "Okmart $name";

                # 格式化電話號碼 (取第一組電話)
                my $formatted_phone = format_phone($phone);

                # 處理地址 - 移除城市和區域名稱
                my $detailed_address = $address;
                $detailed_address =~ s/^\Q$city_name\E//;
                $detailed_address =~ s/^\Q$area\E//;
                $detailed_address =~ s/^\s+|\s+$//g;

                # 寫入 CSV
                my @csv_row = (
                    $name,
                    $formatted_phone,
                    $city_name,
                    $area,
                    $detailed_address,
                    '',    # latitude (空白)
                    ''     # longitude (空白)
                );

                print $fh_csv join( ',', @csv_row ) . "\n";
                print "      Added: $name\n";
            }

            # 避免過於頻繁的請求
            sleep(0.5);
        }

        # 區域間的延遲
        sleep(1);
    }

    close $fh_csv;
    print "Saved data to $csv_file\n";

    # 城市間的延遲
    sleep(2);
}

# 電話號碼格式化函數
sub format_phone {
    my $phone = shift;

    # 取第一組電話（以逗號或空格分隔）
    $phone = ( split /[,\s]+/, $phone )[0];

    # 移除所有非數字字符
    my $digits = $phone;
    $digits =~ s/\D//g;

    # 格式化為 dd-dddd-dddd 或 dd-ddd-dddd
    if ( $digits =~ /^(\d{2})(\d{4})(\d{4})$/ ) {
        return "$1-$2-$3";
    }
    elsif ( $digits =~ /^(\d{2})(\d{3})(\d{4})$/ ) {
        return "$1-$2-$3";
    }
    elsif ( $digits =~ /^(\d{2})(\d{7})$/ ) {
        return "$1-$2";
    }
    else {
        return $phone;    # 無法格式化時返回原始值
    }
}

print "All done!\n";

__END__
