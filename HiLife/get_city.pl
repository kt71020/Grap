#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

# 確保 UTF-8 輸出
binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";

use LWP::UserAgent;
use HTML::TreeBuilder::XPath;
use Encode qw(decode);

print "HiLife 萊爾富便利商店 - 城市代碼分析\n";
print "=" x 50 . "\n";

# 初始化 HTTP 客戶端
my $ua = LWP::UserAgent->new(
    agent   => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    timeout => 30,
);

# 目標網址
my $url = 'https://www.hilife.com.tw/storeInquiry_street.aspx';

print "正在分析網站: $url\n";

# 發送請求
my $res = $ua->get($url);
if ( !$res->is_success ) {
    die "無法訪問網站: " . $res->status_line . "\n";
}

my $html = decode( 'utf8', $res->content );

# 解析 HTML
my $tree = HTML::TreeBuilder::XPath->new;
$tree->parse($html);
$tree->eof;

# 查找縣市選項
my @city_options = $tree->findnodes('//select[@name="city"]//option[position()>1]');

if ( @city_options == 0 ) {

    # 嘗試其他可能的選擇器
    @city_options = $tree->findnodes('//select//option[contains(text(),"市")] | //select//option[contains(text(),"縣")]');
}

print "\n找到的縣市選項：\n";
print "-" x 30 . "\n";

my %city_map;
foreach my $option (@city_options) {
    my $value = $option->attr('value') || '';
    my $text  = $option->as_text;

    # 清理文字
    $text =~ s/^\s+|\s+$//g;

    if ( $value && $text && $text ne '選擇縣市' ) {
        $city_map{$value} = $text;
        printf "%-10s => %s\n", "'$value'", $text;
    }
}

$tree->delete;

print "\n" . "-" x 30 . "\n";
print "總共找到 " . scalar( keys %city_map ) . " 個縣市\n";

# 如果沒有找到選項，顯示手動分析的城市列表
if ( keys %city_map == 0 ) {
    print "\n⚠️  無法自動解析，使用預設城市列表：\n";
    %city_map = (
        '台北市' => '台北市',
        '基隆市' => '基隆市',
        '新北市' => '新北市',
        '宜蘭縣' => '宜蘭縣',
        '新竹縣' => '新竹縣',
        '桃園市' => '桃園市',
        '苗栗縣' => '苗栗縣',
        '台中市' => '台中市',
        '彰化縣' => '彰化縣',
        '南投縣' => '南投縣',
        '嘉義縣' => '嘉義縣',
        '雲林縣' => '雲林縣',
        '台南市' => '台南市',
        '高雄市' => '高雄市',
        '屏東縣' => '屏東縣',
        '新竹市' => '新竹市',
        '嘉義市' => '嘉義市',
    );

    for my $city ( sort keys %city_map ) {
        printf "%-10s => %s\n", "'$city'", $city_map{$city};
    }
}

print "\n✅ 城市代碼分析完成！\n";
print "請將這些代碼用於主爬蟲程式。\n";
