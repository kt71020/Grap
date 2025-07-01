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
use Encode qw(decode);

# 初始化 HTTP 客戶端
my $ua = LWP::UserAgent->new(
    agent =>
'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    cookie_jar => HTTP::Cookies->new,
    timeout    => 30,
);

# 設定額外的 HTTP 標頭
$ua->default_header( 'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' );
$ua->default_header( 'Accept-Language'           => 'zh-TW,zh;q=0.9,en;q=0.8' );
$ua->default_header( 'Accept-Encoding'           => 'gzip, deflate, br' );
$ua->default_header( 'DNT'                       => '1' );
$ua->default_header( 'Connection'                => 'keep-alive' );
$ua->default_header( 'Upgrade-Insecure-Requests' => '1' );

my $BASE_URL = 'https://www.hilife.com.tw/storeInquiry_street.aspx';

print "HiLife 網站結構調試工具\n";
print "=" x 40 . "\n";

# 第一步：獲取主頁面
print "步驟 1: 獲取主頁面...\n";
my $res = $ua->get($BASE_URL);
if ( !$res->is_success ) {
    die "無法訪問主頁面: " . $res->status_line . "\n";
}

my $html = decode( 'utf8', $res->content );
print "主頁面內容長度: " . length($html) . " 字元\n";

# 保存主頁面
open my $fh, '>:encoding(UTF-8)', 'debug_main_page.html' or die "無法保存主頁面: $!";
print $fh $html;
close $fh;
print "主頁面已保存至: debug_main_page.html\n";

# 第二步：分析表單結構
print "\n步驟 2: 分析表單結構...\n";

# 查找縣市選擇器
if ( $html =~ /<select[^>]*name="?city"?[^>]*>(.*?)<\/select>/s ) {
    my $select_content = $1;
    print "找到縣市選擇器，內容:\n";
    print "-" x 30 . "\n";

    while ( $select_content =~ /<option[^>]*value="([^"]*)"[^>]*>([^<]+)<\/option>/g ) {
        my ( $value, $text ) = ( $1, $2 );
        print "值: '$value' => 文字: '$text'\n";
    }
    print "-" x 30 . "\n";
}

# 查找 ViewState
if ( $html =~ /<input[^>]*name="__VIEWSTATE"[^>]*value="([^"]*)"/ ) {
    print "找到 ViewState: " . substr( $1, 0, 50 ) . "...\n";
}
else {
    print "未找到 ViewState\n";
}

# 查找 EventValidation
if ( $html =~ /<input[^>]*name="__EVENTVALIDATION"[^>]*value="([^"]*)"/ ) {
    print "找到 EventValidation: " . substr( $1, 0, 50 ) . "...\n";
}
else {
    print "未找到 EventValidation\n";
}

print "\n✅ 調試完成！請檢查 debug_main_page.html 檔案\n";
