#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

use LWP::UserAgent;
use HTTP::Cookies;
use Encode qw(decode);

# 初始化
my $ua = LWP::UserAgent->new(
    agent =>
'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    cookie_jar => HTTP::Cookies->new,
    timeout    => 30,
);

$ua->default_header( 'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' );
$ua->default_header( 'Accept-Language' => 'zh-TW,zh;q=0.9' );

my $BASE_URL = 'https://www.hilife.com.tw/storeInquiry_street.aspx';

# 輸出檔案
open my $log, '>:encoding(UTF-8)', 'test_log.txt' or die "無法創建日誌檔案: $!";

print $log "=== HiLife 簡化測試 ===\n";
print $log "時間: " . localtime() . "\n\n";

# 測試1: 基本訪問
print $log "測試1: 訪問主頁面\n";
my $res = $ua->get($BASE_URL);
print $log "狀態: " . $res->status_line . "\n";
print $log "內容長度: " . length( $res->content ) . "\n";

if ( $res->is_success ) {
    my $html = decode( 'utf8', $res->content );

    # 保存完整HTML
    open my $html_file, '>:encoding(UTF-8)', 'full_page.html' or warn "無法保存HTML: $!";
    print $html_file $html if $html_file;
    close $html_file       if $html_file;

    print $log "HTML已保存到 full_page.html\n";

    # 分析表單元素
    print $log "\n測試2: 分析表單元素\n";

    # 查找所有select元素
    my @selects = $html =~ /<select[^>]*name="([^"]*)"[^>]*>/g;
    print $log "找到的select元素name屬性: " . join( ', ', @selects ) . "\n";

    # 查找所有input元素
    my @inputs = $html =~ /<input[^>]*name="([^"]*)"[^>]*>/g;
    print $log "找到的input元素name屬性: " . join( ', ', @inputs ) . "\n";

    # 查找所有button/submit元素
    my @buttons = $html =~ /<(?:input[^>]*type="submit"|button)[^>]*(?:name="([^"]*)"[^>]*)?>/g;
    print $log "找到的按鈕元素: " . join( ', ', grep defined, @buttons ) . "\n";

    # 查找ViewState
    if ( $html =~ /<input[^>]*name="__VIEWSTATE"[^>]*value="([^"]*)"/ ) {
        print $log "ViewState長度: " . length($1) . "\n";
    }

    print $log "\n測試完成！\n";
}
else {
    print $log "無法訪問網站: " . $res->status_line . "\n";
}

close $log;

# 在螢幕上顯示完成信息（如果終端工作的話）
print "測試完成！請檢查 test_log.txt 和 full_page.html 檔案\n";
