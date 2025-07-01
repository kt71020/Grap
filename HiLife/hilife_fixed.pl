#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

# 更安全的編碼處理
use open ':std', ':encoding(utf8)';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Request;
use Time::HiRes qw(sleep);
use Encode;

my $BASE_URL = 'https://www.hilife.com.tw/storeInquiry_street.aspx';

print "🔧 HiLife 修正版測試程式\n";
print "目標網站: $BASE_URL\n";
print "=" x 50 . "\n";

# 創建更低調的 User Agent
my $ua = LWP::UserAgent->new(
    agent =>
'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15',
    timeout    => 30,
    cookie_jar => HTTP::Cookies->new(),
);

# 設定基本標頭
$ua->default_header( 'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' );
$ua->default_header( 'Accept-Language' => 'zh-TW,zh;q=0.9' );
$ua->default_header( 'Connection'      => 'keep-alive' );

print "🚀 開始測試連接...\n\n";

# 多階段測試策略
my $success = test_connection();

if ($success) {
    print "\n✅ 連接測試成功！\n";
    print "可以使用此配置更新主程式。\n";
}
else {
    print "\n❌ 所有連接策略都失敗了。\n";
    print "建議檢查網路設定或稍後重試。\n";
}

sub test_connection {

    # 階段1: 測試主頁訪問
    print "📍 階段1: 測試主頁訪問\n";
    my $home_response = $ua->get('https://www.hilife.com.tw/');

    if ( !$home_response->is_success ) {
        print "  ❌ 主頁訪問失敗: " . $home_response->status_line . "\n";
        print "  這可能表示網站完全無法訪問或有 IP 限制\n";
        return 0;
    }

    print "  ✅ 主頁訪問成功！\n";
    print "  回應代碼: " . $home_response->code . "\n";
    print "  內容長度: " . length( $home_response->content ) . " 位元組\n";

    # 等待一下模擬人類行為
    sleep 3;

    # 階段2: 訪問目標頁面
    print "\n🎯 階段2: 訪問門市查詢頁面\n";
    my $req = HTTP::Request->new( GET => $BASE_URL );
    $req->header( 'Referer' => 'https://www.hilife.com.tw/' );

    my $response = $ua->request($req);

    if ( !$response->is_success ) {
        print "  ❌ 目標頁面訪問失敗: " . $response->status_line . "\n";

        # 如果是 403，嘗試其他策略
        if ( $response->code == 403 ) {
            return try_alternative_strategies();
        }

        return 0;
    }

    print "  ✅ 目標頁面訪問成功！\n";
    return analyze_page_content($response);
}

sub try_alternative_strategies {
    print "\n🔄 嘗試替代策略解決 403 錯誤...\n";

    # 策略1: 更換 User-Agent 為手機版
    print "📱 策略1: 使用手機 User-Agent\n";
    $ua->agent(
'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
    );

    sleep 2;
    my $mobile_response = $ua->get($BASE_URL);

    if ( $mobile_response->is_success ) {
        print "  ✅ 手機版策略成功！\n";
        return analyze_page_content($mobile_response);
    }

    print "  ❌ 手機版策略失敗: " . $mobile_response->status_line . "\n";

    # 策略2: 更長的等待時間
    print "\n⏰ 策略2: 延長等待時間\n";
    sleep 10;

    # 重置為原始 User-Agent
    $ua->agent(
'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15'
    );

    my $delayed_response = $ua->get($BASE_URL);

    if ( $delayed_response->is_success ) {
        print "  ✅ 延遲策略成功！\n";
        return analyze_page_content($delayed_response);
    }

    print "  ❌ 延遲策略失敗: " . $delayed_response->status_line . "\n";

    # 策略3: 模擬搜尋引擎
    print "\n🔍 策略3: 模擬搜尋引擎來源\n";
    my $search_req = HTTP::Request->new( GET => $BASE_URL );
    $search_req->header( 'Referer' => 'https://www.google.com/' );

    my $search_response = $ua->request($search_req);

    if ( $search_response->is_success ) {
        print "  ✅ 搜尋引擎策略成功！\n";
        return analyze_page_content($search_response);
    }

    print "  ❌ 搜尋引擎策略失敗: " . $search_response->status_line . "\n";

    return 0;
}

sub analyze_page_content {
    my ($response) = @_;

    print "\n📊 分析頁面內容...\n";

    my $content        = $response->content;
    my $content_length = length($content);

    print "  內容長度: $content_length 位元組\n";

    # 檢查關鍵元素
    my $has_city_select = $content =~ /<select[^>]*name=["']CITY["']/i;
    my $has_area_select = $content =~ /<select[^>]*name=["']AREA["']/i;
    my $has_viewstate   = $content =~ /__VIEWSTATE/i;

    print "  包含城市選單: " .       ( $has_city_select ? "是" : "否" ) . "\n";
    print "  包含地區選單: " .       ( $has_area_select ? "是" : "否" ) . "\n";
    print "  包含 ViewState: " . ( $has_viewstate   ? "是" : "否" ) . "\n";

    # 保存成功的頁面
    if ( $content_length > 1000 && $has_city_select ) {
        eval {
            open my $fh, '>:encoding(UTF-8)', 'working_page.html' or die $!;

            # 嘗試解碼 UTF-8
            my $decoded_content = $content;
            if ( !utf8::is_utf8($content) ) {
                eval { $decoded_content = Encode::decode( 'utf8', $content ); };
            }

            print $fh $decoded_content;
            close $fh;
            print "  💾 成功頁面已保存為 working_page.html\n";
        };

        if ($@) {
            print "  ⚠️ 無法保存頁面: $@\n";
        }

        return 1;    # 成功
    }
    else {
        print "  ⚠️ 頁面內容不完整或不正確\n";
        return 0;    # 失敗
    }
}
