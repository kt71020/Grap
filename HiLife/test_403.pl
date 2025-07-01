#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";

use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Request;
use Encode      qw(decode);
use Time::HiRes qw(sleep);

my $BASE_URL = 'https://www.hilife.com.tw/storeInquiry_street.aspx';

print "=== HiLife 403 繞過測試工具 ===\n";
print "時間: " . localtime() . "\n\n";

# 測試不同的 User-Agent
my @user_agents = (
'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
);

# 測試不同的訪問策略
my $test_count    = 0;
my $success_count = 0;

for my $user_agent (@user_agents) {
    $test_count++;

    print "測試 $test_count: " . substr( $user_agent, 0, 50 ) . "...\n";

    my $ua = LWP::UserAgent->new(
        agent      => $user_agent,
        cookie_jar => HTTP::Cookies->new,
        timeout    => 30,
    );

    # 設定基本標頭
    $ua->default_header( 'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' );
    $ua->default_header( 'Accept-Language' => 'zh-TW,zh;q=0.9,en;q=0.8' );
    $ua->default_header( 'Connection'      => 'keep-alive' );

    # 策略1: 直接訪問
    my $res = $ua->get($BASE_URL);
    if ( $res->is_success ) {
        print "  ✅ 直接訪問成功！\n";
        $success_count++;
        save_successful_result( $res, "direct_$test_count" );
        next;
    }
    print "  ❌ 直接訪問失敗: " . $res->status_line . "\n";

    # 策略2: 先訪問首頁
    sleep 2;
    my $home_res = $ua->get('https://www.hilife.com.tw/');
    if ( $home_res->is_success ) {
        print "  📍 首頁訪問成功，再試目標頁面...\n";
        sleep 2;

        my $req = HTTP::Request->new( GET => $BASE_URL );
        $req->header( 'Referer' => 'https://www.hilife.com.tw/' );
        $res = $ua->request($req);

        if ( $res->is_success ) {
            print "  ✅ 帶 Referer 訪問成功！\n";
            $success_count++;
            save_successful_result( $res, "referer_$test_count" );
            next;
        }
        print "  ❌ 帶 Referer 失敗: " . $res->status_line . "\n";
    }

    # 策略3: 模擬搜尋引擎來源
    sleep 2;
    my $req = HTTP::Request->new( GET => $BASE_URL );
    $req->header( 'Referer' => 'https://www.google.com/search?q=hilife+門市查詢' );
    $res = $ua->request($req);

    if ( $res->is_success ) {
        print "  ✅ Google Referer 成功！\n";
        $success_count++;
        save_successful_result( $res, "google_$test_count" );
        next;
    }
    print "  ❌ Google Referer 失敗: " . $res->status_line . "\n";

    # 測試間隔
    sleep 3;
}

print "\n" . "=" x 50 . "\n";
print "測試總結:\n";
print "總測試次數: $test_count\n";
print "成功次數: $success_count\n";
print "成功率: " . sprintf( "%.1f", ( $success_count / $test_count ) * 100 ) . "%\n";

if ( $success_count > 0 ) {
    print "\n✅ 找到可用的訪問方法！請檢查 successful_*.html 檔案\n";
    print "建議使用成功的 User-Agent 和策略更新主程式\n";
}
else {
    print "\n❌ 所有策略都失敗了\n";
    print "可能需要:\n";
    print "1. 使用代理伺服器\n";
    print "2. 等待更長時間再試\n";
    print "3. 嘗試其他技術方案\n";
}

sub save_successful_result {
    my ( $res, $filename ) = @_;

    open my $fh, '>:encoding(UTF-8)', "successful_$filename.html" or return;
    print $fh decode( 'utf8', $res->content );
    close $fh;

    print "    💾 成功頁面已保存為 successful_$filename.html\n";

    # 簡單分析頁面內容
    my $content    = decode( 'utf8', $res->content );
    my $length     = length($content);
    my $has_form   = $content =~ /<form/i   ? "有" : "無";
    my $has_select = $content =~ /<select/i ? "有" : "無";

    print "    📊 頁面分析: 長度=$length, 表單=$has_form, 下拉選單=$has_select\n";
}
