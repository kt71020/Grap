#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TreeBuilder;
use Encode qw(decode encode);
use JSON::PP;
use Data::Dumper;

# 設定輸出編碼
binmode( STDOUT, ":utf8" );

# 創建 UserAgent
my $ua = LWP::UserAgent->new(
    agent =>
'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
    timeout  => 30,
    ssl_opts => { verify_hostname => 0, SSL_verify_mode => 0 }
);

# 設定完整的瀏覽器標頭
$ua->default_header( 'Accept' =>
'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7'
);
$ua->default_header( 'Accept-Language'    => 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7' );
$ua->default_header( 'Cache-Control'      => 'max-age=0' );
$ua->default_header( 'Sec-Ch-Ua'          => '"Google Chrome";v="137", "Chromium";v="137", "Not/A)Brand";v="24"' );
$ua->default_header( 'Sec-Ch-Ua-Mobile'   => '?0' );
$ua->default_header( 'Sec-Ch-Ua-Platform' => '"macOS"' );
$ua->default_header( 'Sec-Fetch-Dest'     => 'document' );
$ua->default_header( 'Sec-Fetch-Mode'     => 'navigate' );
$ua->default_header( 'Sec-Fetch-Site'     => 'same-origin' );
$ua->default_header( 'Sec-Fetch-User'     => '?1' );
$ua->default_header( 'Upgrade-Insecure-Requests' => '1' );

my $base_url = 'https://www.hilife.com.tw/storeInquiry_street.aspx';

print "=== HiLife 城市地區解析程式 ===\n\n";

# 步驟1: 取得初始頁面
print "步驟1: 取得初始頁面...\n";
my $response = $ua->get($base_url);

if ( !$response->is_success ) {
    die "無法取得初始頁面: " . $response->status_line . "\n";
}

my $content = decode( 'utf8', $response->content );
print "成功取得初始頁面 (長度: " . length($content) . " 字元)\n\n";

# 步驟2: 解析HTML，取得城市列表和表單參數
print "步驟2: 解析HTML，取得城市列表...\n";
my $tree = HTML::TreeBuilder->new;
$tree->parse($content);

# 取得城市列表
my $city_select = $tree->look_down( 'name', 'CITY' );
if ( !$city_select ) {
    die "找不到城市選擇框\n";
}

my @city_options = $city_select->find_by_tag_name('option');
my @cities       = ();

foreach my $option (@city_options) {
    my $value = $option->attr('value');
    my $text  = $option->as_text;
    next if !$value || $value eq '';

    push @cities,
      {
        name    => $value,
        display => $text
      };
    print "發現城市: $value ($text)\n";
}

print "共發現 " . scalar(@cities) . " 個城市\n\n";

# 取得表單的隱藏欄位
my $viewstate           = '';
my $viewstate_generator = '';
my $event_validation    = '';

my $viewstate_input = $tree->look_down( 'name', '__VIEWSTATE' );
$viewstate = $viewstate_input->attr('value') if $viewstate_input;

my $viewstate_gen_input = $tree->look_down( 'name', '__VIEWSTATEGENERATOR' );
$viewstate_generator = $viewstate_gen_input->attr('value') if $viewstate_gen_input;

my $event_val_input = $tree->look_down( 'name', '__EVENTVALIDATION' );
$event_validation = $event_val_input->attr('value') if $event_val_input;

print "表單參數:\n";
print "VIEWSTATE: " . ( length($viewstate) > 50 ? substr( $viewstate, 0, 50 ) . "..." : $viewstate ) . "\n";
print "VIEWSTATEGENERATOR: $viewstate_generator\n";
print "EVENTVALIDATION: "
  . ( length($event_validation) > 50 ? substr( $event_validation, 0, 50 ) . "..." : $event_validation ) . "\n\n";

$tree->delete;

# 步驟3: 對每個城市發送POST請求，取得其地區列表
print "步驟3: 取得各城市的地區列表...\n";

my %city_areas      = ();
my $processed_count = 0;

foreach my $city (@cities) {
    my $city_name = $city->{name};
    print "處理城市: $city_name\n";

    # 準備POST資料
    my $post_data = {
        '__EVENTTARGET'        => 'CITY',
        '__EVENTARGUMENT'      => '',
        '__LASTFOCUS'          => '',
        '__VIEWSTATE'          => $viewstate,
        '__VIEWSTATEGENERATOR' => $viewstate_generator,
        '__EVENTVALIDATION'    => $event_validation,
        'CITY'                 => $city_name,
        'AREA'                 => '中正區'                   # 預設值
    };

    # 發送POST請求
    my $post_response = $ua->post(
        $base_url,
        'Content-Type' => 'application/x-www-form-urlencoded',
        'Referer'      => $base_url,
        Content        => $post_data
    );

    if ( !$post_response->is_success ) {
        print "  錯誤: " . $post_response->status_line . "\n";
        next;
    }

    # 解析回應，取得地區列表
    my $response_content = decode( 'utf8', $post_response->content );
    my $response_tree    = HTML::TreeBuilder->new;
    $response_tree->parse($response_content);

    my $area_select = $response_tree->look_down( 'name', 'AREA' );
    if ( !$area_select ) {
        print "  警告: 找不到地區選擇框\n";
        $response_tree->delete;
        next;
    }

    my @area_options = $area_select->find_by_tag_name('option');
    my @areas        = ();

    foreach my $option (@area_options) {
        my $value = $option->attr('value');
        my $text  = $option->as_text;
        next if !$value || $value eq '';

        push @areas,
          {
            name    => $value,
            display => $text
          };
    }

    $city_areas{$city_name} = \@areas;
    print "  發現 " . scalar(@areas) . " 個地區: " . join( ', ', map { $_->{name} } @areas ) . "\n";

    $response_tree->delete;
    $processed_count++;

    # 添加延遲避免被封鎖
    if ( $processed_count < scalar(@cities) ) {
        print "  暫停 2 秒...\n";
        sleep(2);
    }

    print "\n";
}

# 步驟4: 輸出結果
print "=== 解析結果摘要 ===\n";
print "總共處理了 $processed_count 個城市\n\n";

# 輸出到 JSON 檔案
my $json_output = {
    timestamp        => scalar( localtime() ),
    total_cities     => scalar(@cities),
    processed_cities => $processed_count,
    city_areas       => \%city_areas
};

open( my $json_fh, '>:utf8', 'city_areas.json' ) or die "無法創建 JSON 檔案: $!\n";
print $json_fh JSON::PP->new->pretty->encode($json_output);
close($json_fh);

print "已將結果輸出到 city_areas.json\n";

# 輸出到 CSV 檔案
open( my $csv_fh, '>:utf8', 'city_areas.csv' ) or die "無法創建 CSV 檔案: $!\n";
print $csv_fh "城市,地區\n";

foreach my $city_name ( sort keys %city_areas ) {
    my $areas = $city_areas{$city_name};
    foreach my $area (@$areas) {
        print $csv_fh "$city_name,$area->{name}\n";
    }
}
close($csv_fh);

print "已將結果輸出到 city_areas.csv\n";

# 輸出統計資訊
print "\n=== 統計資訊 ===\n";
foreach my $city_name ( sort keys %city_areas ) {
    my $area_count = scalar( @{ $city_areas{$city_name} } );
    print "$city_name: $area_count 個地區\n";
}

print "\n程式執行完成！\n";
