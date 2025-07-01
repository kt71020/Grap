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

# 城市列表 - 僅用於調試
my @cities = qw(台北市);

# 初始化 HTTP 客戶端 - 使用手機 User-Agent 降低風險
my $ua = LWP::UserAgent->new(
    agent =>
'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
    cookie_jar   => HTTP::Cookies->new,
    timeout      => 30,
    max_redirect => 3,
);

# 設定簡化的瀏覽器 HTTP 標頭
$ua->default_header( 'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' );
$ua->default_header( 'Accept-Language' => 'zh-TW,zh;q=0.9' );
$ua->default_header( 'Accept-Encoding' => 'gzip, deflate' );
$ua->default_header( 'Connection'      => 'keep-alive' );

# 常數
my $BASE_URL = 'https://www.hilife.com.tw/storeInquiry_street.aspx';

print "🔧 HiLife 萊爾富門市資訊爬蟲 - 調試版本\n";
print "目標網站: $BASE_URL\n";
print "=" x 60 . "\n";

# 第一步：測試多種連接策略
print "🔍 步驟0: 測試多種連接策略...\n";
my $successful_ua = find_working_strategy();
if ( !$successful_ua ) {
    print "❌ 所有策略都失敗，程式結束\n";
    exit 1;
}

# 使用成功的 User Agent 繼續
$ua = $successful_ua;

# 測試城市
for my $city_name (@cities) {
    print "\n🏙️  處理城市: $city_name...\n";

    # 階層式查詢：取得地區列表
    my $regions = get_city_regions($city_name);

    print "📊 調試資訊:\n";
    print "  - 找到地區數量: " . scalar(@$regions) . "\n";

    if ( @$regions > 0 ) {
        print "  - 地區列表:\n";
        for my $region (@$regions) {
            print "    * $region->{name} (值: $region->{value})\n";
        }

        # 測試第一個地區的門市查詢
        print "\n🏪 測試第一個地區的門市查詢...\n";
        my $test_region = $regions->[0];
        my $stores      = get_region_stores( $city_name, $test_region );

        print "📊 門市查詢結果:\n";
        print "  - 找到門市數量: " . scalar(@$stores) . "\n";

        if ( @$stores > 0 ) {
            print "  - 門市列表（前3個）:\n";
            for my $i ( 0 .. min( 2, $#$stores ) ) {
                my $store = $stores->[$i];
                print "    * $store->{name}\n";
                print "      地址: $store->{address}\n";
                print "      電話: $store->{phone}\n";
            }
        }
    }
    else {
        print "⚠️  未找到任何地區，可能需要檢查選擇器\n";
    }
}

print "\n🎉 調試完成！\n";

# 測試多種策略找到可用的連接方法
sub find_working_strategy {
    my @strategies = (
        {
            name  => "iPhone Safari",
            agent =>
'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
            delay => 2,
        },
        {
            name  => "macOS Safari",
            agent =>
'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15',
            delay => 3,
        },
        {
            name  => "Windows Chrome (舊版)",
            agent =>
'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36',
            delay => 4,
        },
    );

    for my $strategy (@strategies) {
        print "  🧪 測試策略: $strategy->{name}...\n";

        # 創建新的 UA
        my $test_ua = LWP::UserAgent->new(
            agent        => $strategy->{agent},
            cookie_jar   => HTTP::Cookies->new,
            timeout      => 30,
            max_redirect => 3,
        );

        # 設定基本標頭
        $test_ua->default_header( 'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' );
        $test_ua->default_header( 'Accept-Language' => 'zh-TW,zh;q=0.9' );
        $test_ua->default_header( 'Connection'      => 'keep-alive' );

        # 嘗試多步驟訪問
        if ( test_ua_strategy( $test_ua, $strategy->{name} ) ) {
            print "  ✅ 策略 '$strategy->{name}' 成功！\n";
            return $test_ua;
        }

        print "  ❌ 策略 '$strategy->{name}' 失敗\n";
        sleep $strategy->{delay};
    }

    return undef;
}

sub test_ua_strategy {
    my ( $test_ua, $strategy_name ) = @_;

    # 步驟1: 訪問主頁
    my $home_res = $test_ua->get('https://www.hilife.com.tw/');
    if ( !$home_res->is_success ) {
        print "    ❌ 主頁訪問失敗: " . $home_res->status_line . "\n";
        return 0;
    }

    sleep 2;

    # 步驟2: 訪問目標頁面
    my $req = HTTP::Request->new( GET => $BASE_URL );
    $req->header( 'Referer' => 'https://www.hilife.com.tw/' );

    my $res = $test_ua->request($req);
    if ( !$res->is_success ) {
        print "    ❌ 目標頁面訪問失敗: " . $res->status_line . "\n";
        return 0;
    }

    # 檢查頁面內容
    my $content  = $res->content;
    my $has_city = $content =~ /<select[^>]*name="CITY"/i;
    my $has_area = $content =~ /<select[^>]*name="AREA"/i;

    if ( $has_city && $has_area && length($content) > 5000 ) {

        # 保存成功的頁面
        my $filename = "success_${strategy_name}.html";
        $filename =~ s/\s+/_/g;

        eval {
            my $decoded_content = $content;
            unless ( utf8::is_utf8($content) ) {
                eval { $decoded_content = decode( 'utf8', $content ); };
            }

            open my $fh, '>:encoding(UTF-8)', $filename or die $!;
            print $fh $decoded_content;
            close $fh;
            print "    💾 成功頁面已保存為: $filename\n";
        };

        return 1;
    }

    return 0;
}

# 測試網站訪問性
sub test_website_access {
    print "  正在測試多種訪問策略...\n";

    # 策略1: 先訪問主頁
    print "  🏠 策略1: 先訪問主頁建立 session...\n";
    my $home_res = $ua->get('https://www.hilife.com.tw/');

    if ( $home_res->is_success ) {
        print "    ✅ 主頁訪問成功\n";
        sleep 2;

        # 然後訪問目標頁面
        print "  🎯 策略1: 帶 Referer 訪問目標頁面...\n";
        my $req = HTTP::Request->new( GET => $BASE_URL );
        $req->header( 'Referer' => 'https://www.hilife.com.tw/' );

        my $res = $ua->request($req);

        if ( $res->is_success ) {
            print "  ✅ 策略1 成功！\n";
            save_debug_page( $res, 'strategy1' );
            return 1;
        }
        else {
            print "  ❌ 策略1 失敗: " . $res->status_line . "\n";
        }
    }
    else {
        print "    ❌ 主頁訪問失敗: " . $home_res->status_line . "\n";
    }

    # 策略2: 直接訪問
    print "  🚀 策略2: 直接訪問...\n";
    my $res = $ua->get($BASE_URL);

    if ( $res->is_success ) {
        print "  ✅ 策略2 成功！\n";
        save_debug_page( $res, 'strategy2' );
        return 1;
    }
    else {
        print "  ❌ 策略2 失敗: " . $res->status_line . "\n";
    }

    # 策略3: 模擬搜尋引擎來源
    print "  🔍 策略3: 模擬搜尋引擎來源...\n";
    my $req3 = HTTP::Request->new( GET => $BASE_URL );
    $req3->header( 'Referer' => 'https://www.google.com/search?q=hilife+門市查詢' );

    my $res3 = $ua->request($req3);

    if ( $res3->is_success ) {
        print "  ✅ 策略3 成功！\n";
        save_debug_page( $res3, 'strategy3' );
        return 1;
    }
    else {
        print "  ❌ 策略3 失敗: " . $res3->status_line . "\n";
    }

    return 0;
}

sub save_debug_page {
    my ( $res, $prefix ) = @_;

    my $content = $res->content;
    my $decoded_content;

    # 安全的 UTF-8 處理
    eval { $decoded_content = decode( 'utf8', $content ); };

    if ($@) {
        print "    ⚠️ UTF-8 解碼失敗，使用原始內容\n";
        $decoded_content = $content;
    }

    print "  回應長度: " . length($decoded_content) . " 字元\n";

    # 保存頁面
    my $filename = "${prefix}_debug_page.html";
    eval {
        open my $debug_fh, '>:encoding(UTF-8)', $filename or die "無法開啟檔案: $!";
        print $debug_fh $decoded_content;
        close $debug_fh;
        print "  💾 頁面已保存至 $filename\n";
    };

    if ($@) {
        print "    ⚠️ 無法保存頁面: $@\n";
    }

    # 簡單分析頁面內容
    my $has_city = $decoded_content =~ /<select[^>]*name="CITY"/i;
    my $has_area = $decoded_content =~ /<select[^>]*name="AREA"/i;

    print "  📊 頁面內容分析:\n";
    print "    - 包含城市選單: " . ( $has_city ? "是" : "否" ) . "\n";
    print "    - 包含地區選單: " . ( $has_area ? "是" : "否" ) . "\n";
}

# 取得指定城市的地區列表
sub get_city_regions {
    my ($city_name) = @_;
    my @regions;

    print "  🔍 步驟1: 獲取 $city_name 的地區列表...\n";

    # 獲取主頁面
    my $res = $ua->get($BASE_URL);
    if ( !$res->is_success ) {
        warn "  ❌ 無法訪問主頁面: " . $res->status_line;
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

    print "  📋 表單參數:\n";
    print "    ViewState 長度: " . length($viewstate) . "\n";
    print "    EventValidation 長度: " . length($eventvalidation) . "\n";
    print "    ViewStateGenerator: " . ( $viewstategenerator || "無" ) . "\n";

    # 檢查是否找到台北市選項
    my @city_options = $tree->findnodes('//select[@name="CITY" or @id="CITY"]//option');
    print "  🏙️  可用城市選項:\n";
    foreach my $option (@city_options) {
        my $value = $option->attr('value') || '';
        my $text  = trim( $option->as_text );
        print "    - $text ($value)\n";
    }

    $tree->delete;

    # 發送 POST 請求切換城市
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

    print "  📤 發送 POST 請求切換城市到: $city_name\n";

    # 創建 POST 請求
    my $req = HTTP::Request->new( POST => $BASE_URL );
    $req->header( 'Content-Type' => 'application/x-www-form-urlencoded' );
    $req->header( 'Referer'      => $BASE_URL );

    my $content =
      join( '&', map { uri_escape_utf8($_) . '=' . uri_escape_utf8( $ajax_params{$_} ) } keys %ajax_params );
    $req->content($content);

    $res = $ua->request($req);
    if ( !$res->is_success ) {
        warn "  ❌ AJAX 請求失敗: " . $res->status_line;
        return \@regions;
    }

    print "  ✅ POST 請求成功\n";

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

    # 保存 POST 回應用於分析
    open my $debug_fh, '>:encoding(UTF-8)', 'debug_post_response.html' or warn "無法保存回應: $!";
    if ($debug_fh) {
        print $debug_fh $html;
        close $debug_fh;
    }
    print "  POST 回應已保存至 debug_post_response.html\n";

    # 查找地區下拉選單
    my @region_options = $tree->findnodes('//select[@name="AREA" or @id="AREA"]//option[@value!=""]');

    print "  🔍 搜尋地區選項，找到 " . scalar(@region_options) . " 個選項\n";

    foreach my $option (@region_options) {
        my $value = $option->attr('value') || '';
        my $text  = trim( $option->as_text );

        print "    地區選項: '$text' = '$value'\n";

        # 跳過空值和選擇提示項目
        next if $value eq '' || $text eq '' || $text =~ /請選擇|選擇/;

        push @regions,
          {
            name  => $text,
            value => $value,
          };
    }

    $tree->delete;
    return \@regions;
}

# 取得指定地區的門市列表
sub get_region_stores {
    my ( $city_name, $region ) = @_;
    my @stores;

    print "  🏪 查詢地區: $region->{name} 的門市...\n";

    # 重新訪問主頁面
    my $res = $ua->get($BASE_URL);
    if ( !$res->is_success ) {
        warn "  ❌ 無法重新訪問主頁面: " . $res->status_line;
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

    # 準備查詢參數
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

    print "  📤 發送門市查詢請求...\n";

    # 創建 POST 請求
    my $req = HTTP::Request->new( POST => $BASE_URL );
    $req->header( 'Content-Type' => 'application/x-www-form-urlencoded' );
    $req->header( 'Referer'      => $BASE_URL );

    my $content =
      join( '&', map { uri_escape_utf8($_) . '=' . uri_escape_utf8( $search_params{$_} ) } keys %search_params );
    $req->content($content);

    $res = $ua->request($req);
    if ( !$res->is_success ) {
        warn "  ❌ 查詢請求失敗: " . $res->status_line;
        return \@stores;
    }

    print "  ✅ 查詢請求成功\n";

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

    # 保存查詢結果用於分析
    open my $debug_fh, '>:encoding(UTF-8)', 'debug_store_results.html' or warn "無法保存結果: $!";
    if ($debug_fh) {
        print $debug_fh $html;
        close $debug_fh;
    }
    print "  查詢結果已保存至 debug_store_results.html\n";

    # 查找門市資料
    # 嘗試多種可能的表格結構
    my @possible_selectors = (
        '//table//tr[td and count(td) >= 3]',
        '//div[contains(@class, "store")]',
        '//table[contains(@id, "gv")]//tr[td]',
        '//table[contains(@class, "data")]//tr[td]',
    );

    my @rows;
    for my $selector (@possible_selectors) {
        @rows = $tree->findnodes($selector);
        print "  🔍 選擇器 '$selector' 找到 " . scalar(@rows) . " 個結果\n";
        last if @rows > 0;
    }

    foreach my $row (@rows) {
        my @cells = $row->findnodes('./td');
        print "    行有 " . scalar(@cells) . " 個儲存格\n";

        if ( @cells >= 3 ) {
            my $store_name = trim( $cells[0]->as_text );
            my $address    = trim( $cells[1]->as_text );
            my $phone      = trim( $cells[2]->as_text );

            print "    門市: $store_name | $address | $phone\n";

            next unless $store_name && $address && $phone;

            push @stores,
              {
                name    => $store_name,
                address => $address,
                phone   => $phone,
              };
        }
    }

    $tree->delete;
    return \@stores;
}

# 輔助函數
sub get_form_field {
    my ( $tree, $field_name ) = @_;
    my $node = $tree->findnodes("//input[\@name='$field_name']")->[0];
    return $node ? ( $node->attr('value') || '' ) : '';
}

sub trim {
    my $text = shift;
    return '' unless defined $text;
    $text =~ s/^\s+|\s+$//g;
    return $text;
}

sub min {
    my ( $a, $b ) = @_;
    return $a < $b ? $a : $b;
}
