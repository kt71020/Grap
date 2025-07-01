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

# %city_map = ( '01' => '台北市', );

# Initialize HTTP client
my $ua = LWP::UserAgent->new(
    agent      => 'Mozilla/5.0 (Macintosh; Intel Mac OS X)',
    cookie_jar => HTTP::Cookies->new,
);
$ua->requests_redirectable( [ 'GET', 'HEAD' ] );

# Constants
my $BASE_URL = 'https://emap.pcsc.com.tw/emap.aspx';
my $AJAX_URL = 'https://emap.pcsc.com.tw/EMapSDK.aspx';

# Step 1: 下載首頁一次並存，供後續使用
my $res = $ua->get($BASE_URL);
die "GET $BASE_URL failed: " . $res->status_line unless $res->is_success;
my $html = decode( 'utf8', $res->content );
open my $fh_base, '>:encoding(UTF-8)', 'page1.html' or die $!;
print $fh_base $html;
close $fh_base;
print "Saved page1.html\n";

# 遍歷每個城市代碼與名稱
for my $CITY_CODE ( sort keys %city_map ) {
    my $CITY_NAME = $city_map{$CITY_CODE};
    print "Processing city $CITY_CODE: $CITY_NAME...\n";

    # Step 2: 取得鄉鎮市區列表
    my $town_payload = sprintf( "commandid=GetTown&cityid=%s&leftMenuChecked=36", uri_escape_utf8($CITY_CODE) );
    $res = $ua->post(
        $AJAX_URL,
        'Content-Type' => 'application/x-www-form-urlencoded; charset=UTF-8',
        Content        => $town_payload,
    );
    die "POST GetTown failed for $CITY_CODE: " . $res->status_line
      unless $res->is_success;
    my $xml_content = decode( 'utf8', $res->content );

    # 解析區域名稱
    my @regions;
    while ( $xml_content =~ m|<TownName>([^<]+)</TownName>|g ) {
        push @regions, $1;
    }

    # 準備 CSV 檔案和 XML 除錯目錄
    my $csv_dir = 'csv';
    my $xml_dir = 'xml';
    mkdir $csv_dir unless -d $csv_dir;
    mkdir $xml_dir unless -d $xml_dir;
    my $csv_file = "$csv_dir/$CITY_CODE.csv";
    open my $fh_csv, '>:encoding(UTF-8)', $csv_file or die $!;

    # print $fh_csv "name,phone,city,region,detailed_address,latitude,longitude\n";

    # Step 3: 依各區查詢並寫入 CSV
    for my $region (@regions) {
        my $city_enc = uri_escape_utf8($CITY_NAME);
        my $town_enc = uri_escape_utf8($region);
        my $payload  = sprintf(
"commandid=SearchStore&city=%s&town=%s&roadname=&ID=&StoreName=&SpecialStore_Kind=&leftMenuChecked=36&address=",
            $city_enc, $town_enc );
        $res = $ua->post(
            $AJAX_URL,
            'Content-Type' => 'application/x-www-form-urlencoded; charset=UTF-8',
            Content        => $payload,
        );
        die "POST SearchStore failed for $CITY_CODE-$region: " . $res->status_line
          unless $res->is_success;

        my $xml = decode( 'utf8', $res->content );

        # # 將 $xml 寫入檔案供除錯用
        # open my $fh_xml, '>:encoding(UTF-8)', "xml/$CITY_CODE-$region.xml" or die $!;
        # print $fh_xml $xml;
        # close $fh_xml;
        # print "Saved xml/$CITY_CODE-$region.xml\n";

        while ( $xml =~
m|<GeoPosition>.*?<POIName>([^<]+)</POIName>.*?<X>([^<]+)</X>.*?<Y>([^<]+)</Y>.*?<Telno>([^<]+)</Telno>.*?<Address>([^<]+)</Address>|sg
          )
        {
            my ( $name, $tel_raw, $addr, $lat, $lng ) =
              map { my $x = $_; $x =~ s/^\s+|\s+$//g; $x } ( $1, $4, $5, $3, $2 );

            # 前綴店名前綴
            $name = "統一超商 CITY CAFE $name";

            # 格式化電話
            ( my $digits = $tel_raw ) =~ s/\D//g;
            my $phone;
            if ( $digits =~ /^(\d{2})(\d{4})(\d{4})$/ ) {
                $phone = "$1-$2-$3";
            }

            elsif ( $digits =~ /^(\d{2})(\d{7})$/ ) {
                $phone = "$1-$2";
            }
            else {
                $phone = $tel_raw;
            }

            # 去除地址前綴
            $addr =~ s/^\Q$CITY_NAME$region\E//;

            # 經緯度
            my $latu = $lat / 1000000;
            my $lngu = $lng / 1000000;
            print $fh_csv join( ',', $name, $phone, $CITY_NAME, $region, $addr, $latu, $lngu ), "\n";
        }

    }

    close $fh_csv;
    print "Saved store data to $csv_file\n";
    sleep 10;
}

__END__
