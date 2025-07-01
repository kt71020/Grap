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

# 基本設定
my $BASE_URL   = 'https://emap.pcsc.com.tw/emap.aspx';
my $AJAX_URL   = 'https://emap.pcsc.com.tw/EMapSDK.aspx';
my $PAGE1_FILE = 'page1.html';
my $TOWN_XML   = 'page2_town.html';
my $CITY_NAME  = '台北市';
my $CITY_CODE  = '01';

# 初始化 UA
my $ua = LWP::UserAgent->new(
    agent      => 'Mozilla/5.0 (Macintosh; Intel Mac OS X)',
    cookie_jar => HTTP::Cookies->new,
);
$ua->requests_redirectable( [ 'GET', 'HEAD' ] );

# ------------------------------------------------------------
# Step 1: 下載首頁並存檔
# ------------------------------------------------------------
my $res = $ua->get($BASE_URL);
die "GET $BASE_URL failed: " . $res->status_line unless $res->is_success;
my $html = decode( 'utf8', $res->content );
open my $fh1, '>:encoding(UTF-8)', $PAGE1_FILE or die $!;
print $fh1 $html;
close $fh1;
print "Saved $PAGE1_FILE\n";

# 建立 DOM 解析器並列出可選城市
my $tree = HTML::TreeBuilder::XPath->new;
$tree->parse($html);
print "Available Cities (id => name):\n";
for my $node ( $tree->findnodes('//div[@id="tw"]/div/a') ) {
    printf "%s => %s\n", $node->attr('id'), $node->as_text;
}

# ------------------------------------------------------------
# Step 2: 清理 DOM
# ------------------------------------------------------------
$tree->delete;

# ------------------------------------------------------------
# Step 3: 取得鄉鎮市區列表
# ------------------------------------------------------------
my $town_payload = sprintf( "commandid=GetTown&cityid=%s&leftMenuChecked=", uri_escape_utf8($CITY_CODE) );
$res = $ua->post(
    $AJAX_URL,
    'Content-Type' => 'application/x-www-form-urlencoded; charset=UTF-8',
    Content        => $town_payload,
);
die "POST GetTown failed: " . $res->status_line unless $res->is_success;
my $xml_content = decode( 'utf8', $res->content );
open my $fh2, '>:encoding(UTF-8)', $TOWN_XML or die $!;
print $fh2 $xml_content;
close $fh2;
print "Saved XML response to $TOWN_XML\n";

# 解析 TownName
my @regions;
while ( $xml_content =~ m|<TownName>([^<]+)</TownName>|g ) {
    push @regions, $1;
}

# ------------------------------------------------------------
# Step 4: 針對所有區域, 抓取店鋪並輸出到單一 CSV
# ------------------------------------------------------------
my $csv_file = "$CITY_CODE.csv";
open my $fh3, '>:encoding(UTF-8)', $csv_file or die $!;

# 新格式表頭: name,phone,city,region,detailed_address
print $fh3 "name,phone,city,region,detailed_address\n";

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
    die "POST SearchStore failed for $region: " . $res->status_line unless $res->is_success;

    my $xml = decode( 'utf8', $res->content );

    # 修正匹配，允許中間有其他標籤
    while ( $xml =~
        m|<GeoPosition>.*?<POIName>([^<]+)</POIName>.*?<Telno>([^<]+)</Telno>.*?<Address>([^<]+)</Address>|sg
      )
    {
        my ( $name, $tel_raw, $addr ) = map { my $x = $_; $x =~ s/^\s+|\s+$//g; $x } ( $1, $2, $3 );

        # 格式化電話 (02)28625528 -> 02-2862-5528
        my ($digits) = $tel_raw =~ /(\d+)/;
        my $phone = $digits;
        if ( $phone =~ /^(\d{2})(\d{4})(\d{4})$/ ) {
            $phone = "$1-$2-$3";
        }

        # 寫入 CSV: name,phone,city,region,detailed_address
        print $fh3 join( ',', $name, $phone, $CITY_NAME, $region, $addr ), "\n";
    }
}

close $fh3;
print "Saved all store data to $csv_file\n";

__END__
