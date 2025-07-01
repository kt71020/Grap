#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

# 確保 UTF-8 輸出
binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";

use File::Glob qw(glob);

print "開始合併 HiLife 萊爾富門市檔案...\n";
print "=" x 50 . "\n";

# 輸出檔案
my $output_file = 'Shop_list.csv';

# 開啟輸出檔案
open my $out_fh, '>:encoding(UTF-8)', $output_file or die "無法開啟 $output_file: $!";

# 寫入標題行
print $out_fh "name,phone,city,region,detailed_address,latitude,longitude\n";

# 獲取所有 CSV 檔案
my @csv_files = glob('csv/*.csv');
@csv_files = sort @csv_files;

if ( @csv_files == 0 ) {
    die "錯誤: 在 csv/ 目錄下沒有找到任何 CSV 檔案！\n";
}

print "找到 " . scalar(@csv_files) . " 個 CSV 檔案\n";
print "-" x 30 . "\n";

my $total_stores = 0;
my %city_count;

# 合併所有檔案
foreach my $csv_file (@csv_files) {
    print "處理檔案: $csv_file\n";

    open my $in_fh, '<:encoding(UTF-8)', $csv_file or do {
        warn "無法開啟 $csv_file: $!";
        next;
    };

    my $line_count  = 0;
    my $store_count = 0;

    while ( my $line = <$in_fh> ) {
        $line_count++;

        # 跳過標題行
        if ( $line_count == 1 ) {
            next;
        }

        chomp $line;
        next if $line =~ /^\s*$/;    # 跳過空行

        print $out_fh $line . "\n";
        $store_count++;
        $total_stores++;

        # 統計城市資訊
        my @fields = split /,/, $line;
        if ( @fields >= 3 ) {
            my $city = $fields[2];
            $city =~ s/^"//;    # 移除開頭引號
            $city =~ s/"$//;    # 移除結尾引號
            $city_count{$city}++;
        }
    }

    close $in_fh;
    print "  併入 $store_count 家門市\n";
}

close $out_fh;

print "\n" . "=" x 50 . "\n";
print "✅ 合併完成！\n";
print "📁 輸出檔案: $output_file\n";
print "📊 統計資訊:\n";
print "   - 處理檔案: " . scalar(@csv_files) . " 個\n";
print "   - 總門市數: $total_stores 家\n";
print "   - 檔案大小: " . ( -s $output_file ) . " 位元組\n";

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
    print "總門市數: $total_stores 家\n";
}

print "\n🎉 HiLife 萊爾富門市資料合併完成！\n";
