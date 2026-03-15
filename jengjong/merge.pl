#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

# 確保 UTF-8 輸出
binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";

use File::Glob qw(:glob);

print "門市資料合併程式\n";
print "=" x 50 . "\n";

# 檢查來源目錄
my $csv_dir = 'csv';
unless ( -d $csv_dir ) {
    die "錯誤：找不到 $csv_dir 目錄！請先執行 grap.pl\n";
}

# 檢查 Shop_info.csv
my $shop_info_file = 'Shop_info.csv';
unless ( -f $shop_info_file ) {
    warn "警告：找不到 $shop_info_file，將只合併門市列表\n";
}

# 建立門市列表檔案
my $shop_list_file = 'Shop_list.csv';
print "建立門市列表：$shop_list_file\n";

open my $fh_list, '>:encoding(UTF-8)', $shop_list_file or die "無法建立 $shop_list_file: $!";

# print $fh_list "name,phone,city,region,detailed_address,latitude,longitude\n";

# 合併所有城市的 CSV 檔案
my @csv_files    = bsd_glob("$csv_dir/*.csv");
my $total_stores = 0;
my %city_stats   = ();

print "找到 " . scalar(@csv_files) . " 個城市檔案\n";

foreach my $csv_file ( sort @csv_files ) {
    print "處理：$csv_file\n";

    open my $fh_csv, '<:encoding(UTF-8)', $csv_file or do {
        warn "無法開啟 $csv_file: $!";
        next;
    };

    # 跳過標題行
    my $header = <$fh_csv>;

    my $city_count = 0;
    while ( my $line = <$fh_csv> ) {
        chomp $line;
        next if $line =~ /^\s*$/;    # 跳過空行

        print $fh_list $line . "\n";
        $city_count++;
        $total_stores++;

        # 統計城市門市數量
        if ( $line =~ /^[^,]*,[^,]*,([^,]+),/ ) {
            my $city = $1;
            $city =~ s/"//g;    # 移除引號
            $city_stats{$city}++;
        }
    }

    close $fh_csv;
    print "  合併 $city_count 筆門市資料\n";
}

close $fh_list;

# 建立完整資料檔案（如果 Shop_info.csv 存在）
my $shop_menu_file = 'Shop_menu.csv';

if ( -f $shop_info_file ) {
    print "\n建立完整資料檔案：$shop_menu_file\n";

    open my $fh_menu, '>:encoding(UTF-8)', $shop_menu_file or die "無法建立 $shop_menu_file: $!";

    # 先複製商店資訊
    open my $fh_info, '<:encoding(UTF-8)', $shop_info_file or die "無法開啟 $shop_info_file: $!";
    while ( my $line = <$fh_info> ) {
        print $fh_menu $line;
    }
    close $fh_info;

    # 再加入門市列表

    open my $fh_list2, '<:encoding(UTF-8)', $shop_list_file or die "無法開啟 $shop_list_file: $!";
    while ( my $line = <$fh_list2> ) {
        print $fh_menu $line;
    }
    close $fh_list2;
    close $fh_menu;

    print "完整資料已儲存至 $shop_menu_file\n";
}
else {
    print "\n跳過建立完整資料檔案（缺少 $shop_info_file）\n";
}

# 顯示統計資訊
print "\n" . "=" x 50 . "\n";
print "合併完成統計：\n";
print "總門市數量：$total_stores\n";
print "\n各城市門市分布：\n";

foreach my $city ( sort keys %city_stats ) {
    printf "  %-10s: %3d 間\n", $city, $city_stats{$city};
}

print "\n輸出檔案：\n";
print "  - $shop_list_file（門市列表）\n";
print "  - $shop_menu_file（完整資料）\n" if -f $shop_info_file;

print "\n" . "=" x 50 . "\n";
print "資料合併程式執行完成！\n";
