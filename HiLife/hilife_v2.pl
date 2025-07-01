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

# 城市列表（用於測試）
# 城市列表 - 全台灣 17 個縣市
my @cities = qw(
  台北市 基隆市 新北市 宜蘭縣 新竹縣 桃園市 苗栗縣
  台中市 彰化縣 南投縣 嘉義縣 雲林縣 台南市 高雄市
  屏東縣 新竹市 嘉義市
);

# 初始化 HTTP 客戶端
my $ua = LWP::UserAgent->new(
    agent =>
'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    cookie_jar => HTTP::Cookies->new,
    timeout    => 30,
);

# 設定 HTTP 標頭
$ua->default_header( 'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' );
$ua->default_header( 'Accept-Language'           => 'zh-TW,zh;q=0.9,en;q=0.8' );
$ua->default_header( 'Connection'                => 'keep-alive' );
$ua->default_header( 'Upgrade-Insecure-Requests' => '1' );

# 常數
my $BASE_URL = 'https://www.hilife.com.tw/storeInquiry_street.aspx';

# 建立輸出目錄
my $csv_dir = 'csv';
mkdir $csv_dir unless -d $csv_dir;

print "HiLife 萊爾富門市資訊爬蟲 v2.0 (階層式查詢)\n";
print "目標網站: $BASE_URL\n";
print "=" x 60 . "\n";

# 遍歷每個城市
for my $city_name (@cities) {
    print "處理城市: $city_name...\n";

    # 準備 CSV 檔案
    my $safe_city_name = $city_name;
    $safe_city_name =~ s/[縣市]//g;
    my $csv_file = "$csv_dir/$safe_city_name.csv";

    open my $fh_csv, '>:encoding(UTF-8)', $csv_file or die "無法開啟 $csv_file: $!";
    print $fh_csv "name,phone,city,region,detailed_address,latitude,longitude\n";

    my $total_stores = 0;

    # 階層式查詢：先取得地區列表，再查詢各地區的門市
    my $regions = get_city_regions($city_name);

    if ( @$regions == 0 ) {
        print "  ⚠️  $city_name: 未找到地區資料\n";
        close $fh_csv;
        next;
    }

    print "  找到 " . scalar(@$regions) . " 個地區\n";

    # 遍歷每個地區
    for my $region (@$regions) {
        print "    查詢地區: $region->{name}...\n";

        my $stores_data = get_region_stores( $city_name, $region );

        foreach my $store (@$stores_data) {

            # 處理店名
            my $formatted_name = "HiLife " . $store->{name};

            # 處理電話格式
            my $formatted_phone = format_phone( $store->{phone} );

            # 解析地址
            my $detailed_address = parse_address( $store->{address}, $city_name, $region->{name} );

            # HiLife 網站沒有提供經緯度
            my $latitude  = '';
            my $longitude = '';

            # 寫入 CSV
            my $csv_line = join( ',',
                quote_csv($formatted_name),
                quote_csv($formatted_phone),
                quote_csv($city_name),
                quote_csv( $region->{name} ),
                quote_csv($detailed_address),
                $latitude, $longitude );

            print $fh_csv $csv_line . "\n";
            $total_stores++;

            print "      📍 $formatted_name - $formatted_phone\n";
        }

        # 地區間的延遲
        sleep 2;
    }

    close $fh_csv;
    print "  ✅ $city_name 完成，共抓取 $total_stores 個門市，儲存至 $csv_file\n";

    # 城市間的延遲
    sleep 5;
}

print "\n🎉 HiLife 萊爾富門市資訊爬取完成！\n";

# 第一階段：取得指定城市的地區列表
sub get_city_regions {
    my ($city_name) = @_;
    my @regions;

    print "    步驟1: 獲取 $city_name 的地區列表...\n";

    # 訪問主頁面
    my $res = $ua->get($BASE_URL);
    if ( !$res->is_success ) {
        warn "無法訪問主頁面: " . $res->status_line;
        return \@regions;
    }

    my $html = decode( 'utf8', $res->content );
    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse($html);
    $tree->eof;

    # 獲取表單參數
    my $viewstate          = get_form_field( $tree, '__VIEWSTATE' );
    my $eventvalidation    = get_form_field( $tree, '__EVENTVALIDATION' );
    my $viewstategenerator = get_form_field( $tree, '__VIEWSTATEGENERATOR' );

    $tree->delete;

    # 發送 AJAX 請求取得地區列表
    # 這通常是 POST 請求到原始 URL 或特定的 AJAX 端點
    my %ajax_params = (
        '__VIEWSTATE'          => $viewstate,
        '__EVENTVALIDATION'    => $eventvalidation,
        '__VIEWSTATEGENERATOR' => $viewstategenerator,
        '__EVENTTARGET'        => 'ddlCity',             # 觸發 AJAX 的控制項
        '__EVENTARGUMENT'      => '',
        'ddlCity'              => $city_name,
    );

    # 移除空參數
    for my $key ( keys %ajax_params ) {
        delete $ajax_params{$key} if !defined $ajax_params{$key} || $ajax_params{$key} eq '';
    }

    # 發送 AJAX 請求
    $res = $ua->post( $BASE_URL, \%ajax_params );
    if ( !$res->is_success ) {
        warn "AJAX 請求失敗: " . $res->status_line;
        return \@regions;
    }

    # 解析回應中的地區選項
    $html = decode( 'utf8', $res->content );
    $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse($html);
    $tree->eof;

    # 查找地區下拉選單
    my @region_options = $tree->findnodes(
'//select[@name="ddlRegion" or @name="ddlArea" or contains(@id, "Region") or contains(@id, "Area")]//option[@value!=""]'
    );

    foreach my $option (@region_options) {
        my $value = $option->attr('value') || '';
        my $text  = trim( $option->as_text );

        next if $value eq '' || $text eq '';

        push @regions,
          {
            name  => $text,
            value => $value,
          };
    }

    $tree->delete;

    print "    找到 " . scalar(@regions) . " 個地區: " . join( ', ', map { $_->{name} } @regions ) . "\n";

    return \@regions;
}

# 第二階段：取得指定地區的門市列表
sub get_region_stores {
    my ( $city_name, $region ) = @_;
    my @stores;

    # 重新訪問主頁面以獲取新的表單狀態
    my $res = $ua->get($BASE_URL);
    if ( !$res->is_success ) {
        warn "無法重新訪問主頁面: " . $res->status_line;
        return \@stores;
    }

    my $html = decode( 'utf8', $res->content );
    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse($html);
    $tree->eof;

    # 獲取表單參數
    my $viewstate          = get_form_field( $tree, '__VIEWSTATE' );
    my $eventvalidation    = get_form_field( $tree, '__EVENTVALIDATION' );
    my $viewstategenerator = get_form_field( $tree, '__VIEWSTATEGENERATOR' );

    $tree->delete;

    # 準備查詢參數
    my %search_params = (
        '__VIEWSTATE'          => $viewstate,
        '__EVENTVALIDATION'    => $eventvalidation,
        '__VIEWSTATEGENERATOR' => $viewstategenerator,
        'ddlCity'              => $city_name,
        'ddlRegion'            => $region->{value},
        'ddlArea'              => $region->{value},
        'Button1'              => '查詢',
        'btnSearch'            => '查詢',
    );

    # 移除空參數
    for my $key ( keys %search_params ) {
        delete $search_params{$key} if !defined $search_params{$key} || $search_params{$key} eq '';
    }

    # 發送查詢請求
    $res = $ua->post( $BASE_URL, \%search_params );
    if ( !$res->is_success ) {
        warn "查詢請求失敗: " . $res->status_line;
        return \@stores;
    }

    # 解析門市列表
    $html = decode( 'utf8', $res->content );
    $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse($html);
    $tree->eof;

    # 查找門市資料表格
    my @rows = $tree->findnodes(
'//table[@id="gvStoreList"]//tr[td] | //table[contains(@class, "store")]//tr[td] | //table//tr[td and position()>1]'
    );

    foreach my $row (@rows) {
        my @cells = $row->findnodes('./td');
        next if @cells < 3;

        my $store_name = trim( $cells[0]->as_text );
        my $address    = trim( $cells[1]->as_text );
        my $phone      = trim( $cells[2]->as_text );

        # 清理資料
        $address    =~ s/\s*\[.*?\]\s*//g;    # 移除地圖連結
        $store_name =~ s/^\s*HiLife\s*//i;    # 移除重複的 HiLife 前綴

        next unless $store_name && $address && $phone;

        push @stores,
          {
            name    => $store_name,
            address => $address,
            phone   => $phone,
          };
    }

    $tree->delete;
    return \@stores;
}

# 輔助函數：從表單中獲取隱藏欄位值
sub get_form_field {
    my ( $tree, $field_name ) = @_;
    my $node = $tree->findnodes("//input[\@name='$field_name']")->[0];
    return $node ? ( $node->attr('value') || '' ) : '';
}

# 輔助函數：解析地址
sub parse_address {
    my ( $address, $city_name, $region_name ) = @_;

    # 移除郵遞區號、城市名稱和地區名稱
    $address =~ s/^\d{3}//;
    $address =~ s/^\Q$city_name\E//;
    $address =~ s/^\Q$region_name\E//;

    return trim($address);
}

# 輔助函數：清理文字
sub trim {
    my $text = shift;
    return '' unless defined $text;
    $text =~ s/^\s+|\s+$//g;
    return $text;
}

# 輔助函數：格式化電話號碼
sub format_phone {
    my $phone = shift;
    return '' unless defined $phone;

    $phone =~ s/\D//g;    # 移除非數字字符

    if ( length($phone) == 10 && $phone =~ /^0/ ) {

        # 10位數手機號碼或市話：0912-345-678 或 02-1234-5678
        $phone =~ s/^(\d{2})(\d{4})(\d{4})$/$1-$2-$3/;
    }
    elsif ( length($phone) == 9 ) {

        # 9位數市話：02-123-4567
        $phone =~ s/^(\d{2})(\d{3})(\d{4})$/$1-$2-$3/;
    }

    return $phone;
}

# 輔助函數：CSV 格式化
sub quote_csv {
    my $text = shift;
    return '' unless defined $text;

    # 如果包含逗號、引號或換行符，需要用引號包圍
    if ( $text =~ /[,"\n\r]/ ) {
        $text =~ s/"/""/g;    # 雙引號要轉義
        $text = "\"$text\"";
    }

    return $text;
}
