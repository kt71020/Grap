#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";

use LWP::UserAgent;
use HTML::TreeBuilder::XPath;
use URI::Escape qw(uri_escape_utf8);
use Encode      qw(decode);

# 測試抓取台北市資料
my $ua = LWP::UserAgent->new(
    agent   => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    timeout => 30,
);

my $url = 'https://www.wu-tau.com/store.php?act=query&city_id=7';
print "測試 URL: $url\n";

my $res = $ua->get($url);
if ( !$res->is_success ) {
    die "GET 失敗: " . $res->status_line;
}

my $html = decode( 'utf8', $res->content );
print "HTML 長度: " . length($html) . " 字元\n";

# 建立解析器
my $tree = HTML::TreeBuilder::XPath->new;
$tree->parse($html);
$tree->eof;

# 測試不同的選擇器
my @selectors = (
    '//table[@class="store-table"]',     '//table[@class="store-table"]//tbody/tr',
    '//table[@class="store-table"]//tr', '//tbody/tr',
    '//tr',
);

for my $selector (@selectors) {
    my @nodes = $tree->findnodes($selector);
    print "選擇器 '$selector': 找到 " . scalar(@nodes) . " 個節點\n";
}

# 檢查所有 table 標籤的 class
my @tables = $tree->findnodes('//table');
print "\n找到 " . scalar(@tables) . " 個表格:\n";
for my $i ( 0 .. $#tables ) {
    my $class = $tables[$i]->attr('class') || '(無 class)';
    print "表格 $i: class='$class'\n";
}

# 使用更通用的選擇器
my @rows = $tree->findnodes('//tbody/tr');
if ( @rows > 0 ) {
    print "\n第一行資料分析 (使用 //tbody/tr):\n";
    my $first_row = $rows[0];
    my @cells     = $first_row->findnodes('./td');
    print "欄位數量: " . scalar(@cells) . "\n";

    for my $i ( 0 .. $#cells ) {
        my $text = $cells[$i]->as_text;
        $text =~ s/^\s+|\s+$//g;    # 清理空白
        print "欄位 $i: '$text'\n";
    }

    # 檢查是否包含台北市資料
    if ( @cells >= 5 ) {
        my $city = $cells[0]->as_text;
        $city =~ s/^\s+|\s+$//g;
        print "檢測到城市: '$city'\n";
    }
}
else {
    print "\n沒有找到任何資料行\n";
}

$tree->delete;

print "\n調試完成\n";
