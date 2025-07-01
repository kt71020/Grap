#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

# 確保可以檢查 UTF-8 狀態
require utf8;

# 確保 UTF-8 輸出
binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";

use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Request::Common qw(GET POST);
use HTML::TreeBuilder::XPath;
use URI::Escape qw(uri_escape_utf8);
use Encode      qw(decode encode_utf8);
use Time::HiRes qw(sleep);

# 城市列表 - 全台灣 17 個縣市
my @cities = qw(
  台北市 基隆市 新北市 宜蘭縣 新竹縣 桃園市 苗栗縣
  台中市 彰化縣 南投縣 嘉義縣 雲林縣 台南市 高雄市
  屏東縣 新竹市 嘉義市
);

# 初始化 HTTP 客戶端 - 更完整的瀏覽器模擬
my $ua = LWP::UserAgent->new(
    agent =>
'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    cookie_jar   => HTTP::Cookies->new,
    timeout      => 45,
    max_redirect => 10,
);

# 設定完整的瀏覽器 HTTP 標頭
$ua->default_header( 'Accept' =>
'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7'
);
$ua->default_header( 'Accept-Language'           => 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7' );
$ua->default_header( 'Accept-Encoding'           => 'gzip, deflate, br' );
$ua->default_header( 'DNT'                       => '1' );
$ua->default_header( 'Connection'                => 'keep-alive' );
$ua->default_header( 'Upgrade-Insecure-Requests' => '1' );
$ua->default_header( 'Sec-Fetch-Dest'            => 'document' );
$ua->default_header( 'Sec-Fetch-Mode'            => 'navigate' );
$ua->default_header( 'Sec-Fetch-Site'            => 'none' );
$ua->default_header( 'Sec-Fetch-User'            => '?1' );
$ua->default_header( 'sec-ch-ua'          => '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"' );
$ua->default_header( 'sec-ch-ua-mobile'   => '?0' );
$ua->default_header( 'sec-ch-ua-platform' => '"macOS"' );

# 常數
my $BASE_URL = 'https://www.hilife.com.tw/storeInquiry_street.aspx';

# 建立輸出目錄
my $csv_dir = 'csv';
mkdir $csv_dir unless -d $csv_dir;

print "HiLife 萊爾富門市資訊爬蟲 v3.0 (反反爬蟲版本)\n";
print "目標網站: $BASE_URL\n";
print "=" x 60 . "\n";

# 第一步：測試基本連接
print "🔍 步驟0: 測試網站連接性...\n";
my $test_res = test_website_access();
if ( !$test_res ) {
    print "❌ 無法訪問網站，程式結束\n";
    exit 1;
}

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

        # 地區間的延遲（隨機化）
        my $delay = 3 + rand(2);    # 3-5秒隨機延遲
        print "      💤 休息 " . sprintf( "%.1f", $delay ) . " 秒...\n";
        sleep $delay;
    }

    close $fh_csv;
    print "  ✅ $city_name 完成，共抓取 $total_stores 個門市，儲存至 $csv_file\n";

    # 城市間的延遲（隨機化）
    if ( @cities > 1 ) {
        my $delay = 8 + rand(4);    # 8-12秒隨機延遲
        print "💤 城市間休息 " . sprintf( "%.1f", $delay ) . " 秒...\n";
        sleep $delay;
    }
}

print "\n🎉 HiLife 萊爾富門市資訊爬取完成！\n";

# 測試網站訪問性
sub test_website_access {
    print "    正在測試基本連接...\n";

    # 嘗試多種策略
    my @strategies = (
        {
            name   => "標準請求",
            method => sub { return $ua->get($BASE_URL); }
        },
        {
            name   => "帶 Referer 的請求",
            method => sub {
                my $req = HTTP::Request->new( GET => $BASE_URL );
                $req->header( 'Referer' => 'https://www.google.com/' );
                return $ua->request($req);
            }
        },
        {
            name   => "模擬從首頁進入",
            method => sub {

                # 先訪問首頁
                my $home_res = $ua->get('https://www.hilife.com.tw/');
                sleep 2;

                # 再訪問目標頁面
                my $req = HTTP::Request->new( GET => $BASE_URL );
                $req->header( 'Referer' => 'https://www.hilife.com.tw/' );
                return $ua->request($req);
            }
        }
    );

    for my $strategy (@strategies) {
        print "    嘗試: $strategy->{name}...\n";

        my $res = $strategy->{method}();

        if ( $res->is_success ) {
            print "    ✅ $strategy->{name} 成功！\n";
            print "    回應長度: " . length( $res->content ) . " 字元\n";

            # 保存成功的頁面用於分析
            open my $debug_fh, '>:encoding(UTF-8)', 'successful_page.html' or warn "無法保存頁面: $!";
            if ($debug_fh) {
                my $content = $res->content;
                unless ( utf8::is_utf8($content) ) {
                    eval { $content = decode( 'utf8', $content ); };
                }
                print $debug_fh $content;
                close $debug_fh;
            }
            print "    頁面已保存至 successful_page.html\n";

            return 1;
        }
        else {
            print "    ❌ $strategy->{name} 失敗: " . $res->status_line . "\n";
        }

        # 策略間的延遲
        sleep 3;
    }

    return 0;
}

# 第一階段：取得指定城市的地區列表
sub get_city_regions {
    my ($city_name) = @_;
    my @regions;

    print "    步驟1: 獲取 $city_name 的地區列表...\n";

    # 使用成功的訪問策略
    my $res = safe_get_page($BASE_URL);
    if ( !$res || !$res->is_success ) {
        warn "無法訪問主頁面: " . ( $res ? $res->status_line : "請求失敗" );
        return \@regions;
    }

    # 安全處理 UTF-8 內容
    my $html = $res->content;
    unless ( utf8::is_utf8($html) ) {
        eval { $html = decode( 'utf8', $html ); };
        if ($@) {
            $html = $res->content;
        }
    }

    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse($html);
    $tree->eof;

    # 獲取表單參數
    my $viewstate          = get_form_field( $tree, '__VIEWSTATE' );
    my $eventvalidation    = get_form_field( $tree, '__EVENTVALIDATION' );
    my $viewstategenerator = get_form_field( $tree, '__VIEWSTATEGENERATOR' );

    print "    表單參數長度: ViewState=" . length($viewstate) . ", EventValidation=" . length($eventvalidation) . "\n";

    $tree->delete;

    # 添加隨機延遲
    sleep 2 + rand(2);

    # 發送 AJAX 請求取得地區列表（使用正確的欄位名稱）
    my %ajax_params = (
        '__VIEWSTATE'          => $viewstate,
        '__EVENTVALIDATION'    => $eventvalidation,
        '__VIEWSTATEGENERATOR' => $viewstategenerator,
        '__EVENTTARGET'        => 'CITY',
        '__EVENTARGUMENT'      => '',
        'CITY'                 => $city_name,
    );

    # 移除空參數
    for my $key ( keys %ajax_params ) {
        delete $ajax_params{$key} if !defined $ajax_params{$key} || $ajax_params{$key} eq '';
    }

    # 創建 POST 請求
    my $req = HTTP::Request->new( POST => $BASE_URL );
    $req->header( 'Content-Type' => 'application/x-www-form-urlencoded' );
    $req->header( 'Referer'      => $BASE_URL );
    $req->header( 'Origin'       => 'https://www.hilife.com.tw' );

    # 設置請求內容
    my $content =
      join( '&', map { uri_escape_utf8($_) . '=' . uri_escape_utf8( $ajax_params{$_} ) } keys %ajax_params );
    $req->content($content);

    # 發送 AJAX 請求
    $res = $ua->request($req);
    if ( !$res->is_success ) {
        warn "AJAX 請求失敗: " . $res->status_line;
        return \@regions;
    }

    # 解析回應中的地區選項
    $html = $res->content;
    unless ( utf8::is_utf8($html) ) {
        eval { $html = decode( 'utf8', $html ); };
        if ($@) {
            $html = $res->content;
        }
    }

    $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse($html);
    $tree->eof;

    # 查找地區下拉選單（使用正確的欄位名稱）
    my @region_options = $tree->findnodes('//select[@name="AREA" or @id="AREA"]//option[@value!=""]');

    foreach my $option (@region_options) {
        my $value = $option->attr('value') || '';
        my $text  = trim( $option->as_text );

        # 跳過空值和選擇提示項目
        next if $value eq '' || $text eq '' || $text =~ /請選擇|選擇/;

        push @regions, {
            name  => $text,
            value => $value,    # HiLife 使用中文區域名稱作為值
        };
    }

    $tree->delete;

    print "    找到 " . scalar(@regions) . " 個地區: " . join( ', ', map { $_->{name} } @regions ) . "\n";

    return \@regions;
}

# 安全的頁面請求函數
sub safe_get_page {
    my ( $url, $referer ) = @_;

    my $req = HTTP::Request->new( GET => $url );
    $req->header( 'Referer' => $referer ) if $referer;

    my $res = $ua->request($req);

    # 如果失敗，再試一次
    if ( !$res->is_success && $res->code == 403 ) {
        print "    收到 403，等待後重試...\n";
        sleep 5 + rand(3);
        $res = $ua->request($req);
    }

    return $res;
}

# 第二階段：取得指定地區的門市列表
sub get_region_stores {
    my ( $city_name, $region ) = @_;
    my @stores;

    # 重新訪問主頁面以獲取新的表單狀態
    my $res = safe_get_page($BASE_URL);
    if ( !$res || !$res->is_success ) {
        warn "無法重新訪問主頁面: " . ( $res ? $res->status_line : "請求失敗" );
        return \@stores;
    }

    # 安全處理 UTF-8 內容
    my $html = $res->content;
    unless ( utf8::is_utf8($html) ) {
        eval { $html = decode( 'utf8', $html ); };
        if ($@) {
            $html = $res->content;
        }
    }

    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse($html);
    $tree->eof;

    # 獲取表單參數
    my $viewstate          = get_form_field( $tree, '__VIEWSTATE' );
    my $eventvalidation    = get_form_field( $tree, '__EVENTVALIDATION' );
    my $viewstategenerator = get_form_field( $tree, '__VIEWSTATEGENERATOR' );

    $tree->delete;

    # 準備查詢參數（使用正確的欄位名稱）
    my %search_params = (
        '__VIEWSTATE'          => $viewstate,
        '__EVENTVALIDATION'    => $eventvalidation,
        '__VIEWSTATEGENERATOR' => $viewstategenerator,
        'CITY'                 => $city_name,
        'AREA'                 => $region->{value},
        'Button1'              => '查詢',
    );

    # 移除空參數
    for my $key ( keys %search_params ) {
        delete $search_params{$key} if !defined $search_params{$key} || $search_params{$key} eq '';
    }

    # 創建 POST 請求
    my $req = HTTP::Request->new( POST => $BASE_URL );
    $req->header( 'Content-Type' => 'application/x-www-form-urlencoded' );
    $req->header( 'Referer'      => $BASE_URL );
    $req->header( 'Origin'       => 'https://www.hilife.com.tw' );

    my $content =
      join( '&', map { uri_escape_utf8($_) . '=' . uri_escape_utf8( $search_params{$_} ) } keys %search_params );
    $req->content($content);

    # 發送查詢請求
    $res = $ua->request($req);
    if ( !$res->is_success ) {
        warn "查詢請求失敗: " . $res->status_line;
        return \@stores;
    }

    # 解析門市列表
    $html = $res->content;
    unless ( utf8::is_utf8($html) ) {
        eval { $html = decode( 'utf8', $html ); };
        if ($@) {
            $html = $res->content;
        }
    }

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
