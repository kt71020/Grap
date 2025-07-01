#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

# 確保 UTF-8 輸出
binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";

# use File::Glob;

# 城市代碼對照表
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

# 輸出檔案
my $output_file = 'Shop_list.csv ';

print "開始合併悟饕池上飯包檔案...\n";
print "合併架構: Shop_info.csv + Shop_list.csv -> Shop_menu.csv\n";
print "=" x 60 . "\n";

# 檔案路徑
my $info_file = 'Shop_info.csv';
my $list_file = 'Shop_list.csv';
my $menu_file = 'Shop_menu.csv';

# 檢查來源檔案是否存在
unless ( -f $info_file ) {
    die "錯誤: $info_file 不存在！\n";
}

unless ( -f $list_file ) {
    die "錯誤: $list_file 不存在！\n";
}

# 開啟輸出檔案
open my $out_fh, '>:encoding(UTF-8)', $menu_file or die "無法開啟 $menu_file: $!";

print "步驟 1: 複製 Shop_info.csv 內容...\n";

# 複製 Shop_info.csv 的全部內容
open my $info_fh, '<:encoding(UTF-8)', $info_file or die "無法開啟 $info_file: $!";

my $info_lines = 0;
while ( my $line = <$info_fh> ) {
    print $out_fh $line;
    $info_lines++;
}

close $info_fh;
print "  已複製 $info_lines 行商店基本資訊\n";

print "\n步驟 2: 附加分隔線...\n";

# 添加分隔線，分隔線是其他程式用不勿加入
# print $out_fh "\n---,分隔線,門市列表---\n";

print "\n步驟 3: 附加 Shop_list.csv 內容...\n";

# 附加 Shop_list.csv 的全部內容
open my $list_fh, '<:encoding(UTF-8)', $list_file or die "無法開啟 $list_file: $!";

my $list_lines  = 0;
my $store_count = 0;
my %city_count;

while ( my $line = <$list_fh> ) {
    print $out_fh $line;
    $list_lines++;

    # 統計門市數量（跳過標題行）
    if ( $list_lines > 1 ) {
        $store_count++;

        # 簡單解析城市資訊進行統計
        chomp $line;
        my @fields = split /,/, $line;
        if ( @fields >= 3 ) {
            my $city = $fields[2];
            $city =~ s/^"//;    # 移除開頭引號
            $city =~ s/"$//;    # 移除結尾引號
            $city_count{$city}++;
        }
    }
}

close $list_fh;
print "  已複製 $list_lines 行門市列表資料\n";

close $out_fh;

print "\n" . "=" x 60 . "\n";
print "✅ 合併完成！\n";
print "📁 輸出檔案: $menu_file\n";
print "📊 統計資訊:\n";
print "   - 商店基本資訊: $info_lines 行\n";
print "   - 門市列表: $store_count 家門市\n";
print "   - 總檔案大小: " . ( -s $menu_file ) . " 位元組\n";

# 顯示各城市門市統計
if (%city_count) {
    print "\n🏪 各城市門市統計:\n";
    print "-" x 30 . "\n";

    my $total_cities = 0;
    for my $city ( sort keys %city_count ) {
        printf "%-12s: %3d 家\n", $city, $city_count{$city};
        $total_cities++;
    }

    print "-" x 30 . "\n";
    print "涵蓋城市: $total_cities 個\n";
    print "總門市數: $store_count 家\n";
}

print "\n🎉 檔案合併作業完成！\n";

__END__ 
