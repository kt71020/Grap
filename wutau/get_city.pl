#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

# 我要爬蟲一個新的網頁，抓取資料與產生檔案的邏輯與先前大致一樣。
# 網址：https://www.wu-tau.com/store.php
# 由原始網頁取得城市列表

# <select class="select-style" name="city_id"><option value="">選擇縣市</option><option value="7">台北市</option><option value="8">基隆市</option><option value="9">新北市</option><option value="11">宜蘭縣</option><option value="13">新竹縣</option><option value="14">桃園市</option><option value="15">苗栗縣</option><option value="16">台中市</option><option value="17">彰化縣</option><option value="18">南投縣</option><option value="19">嘉義市</option><option value="20">嘉義縣</option><option value="21">雲林縣</option><option value="22">台南市</option><option value="23">高雄市</option><option value="24">澎湖縣</option><option value="25">金門縣</option><option value="26">屏東縣</option><option value="27">台東縣</option><option value="28">花蓮縣</option> </select>

# 修正後的城市映射表
my %city_map = (
    '7'  => '台北市',
    '8'  => '基隆市',
    '9'  => '新北市',
    '11' => '宜蘭縣',
    '13' => '新竹縣',
    '14' => '桃園市',
    '15' => '苗栗縣',
    '16' => '台中市',
    '17' => '彰化縣',
    '18' => '南投縣',
    '19' => '嘉義市',
    '20' => '嘉義縣',
    '21' => '雲林縣',
    '22' => '台南市',
    '23' => '高雄市',
    '24' => '澎湖縣',
    '25' => '金門縣',
    '26' => '屏東縣',
    '27' => '台東縣',
    '28' => '花蓮縣',
);

# 列印城市映射表
print "城市代碼映射表：\n";
for my $code ( sort { $a <=> $b } keys %city_map ) {
    printf "%-3s => %s\n", "'$code'", $city_map{$code};
}
