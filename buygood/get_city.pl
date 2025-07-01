#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

# 確保 UTF-8 輸出
binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";

print "梁社漢排骨 城市代碼對照表\n";
print "=" x 50 . "\n";

# 根據 grap.md 中提到的 HTML select 選項建立城市對照表
my @cities = (
    "基隆市", "台北市", "新北市", "桃園市", "新竹市", "新竹縣", "苗栗縣", "台中市", "彰化縣", "南投縣",
    "雲林縣", "嘉義市", "嘉義縣", "台南市", "高雄市", "屏東縣", "宜蘭縣", "台東縣", "花蓮縣", "金門縣"
);

print "發現 " . scalar(@cities) . " 個城市：\n\n";

my $index = 1;
for my $city (@cities) {
    printf "%2d. %s\n", $index, $city;
    $index++;
}

print "\n" . "=" x 50 . "\n";
print "城市代碼對照表產生完成\n";
print "注意：梁社漢排骨使用城市名稱作為查詢參數，不是數字代碼\n";
