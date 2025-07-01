# 將 csv/01.csv 的資料，併入Shop_711.csv 之後，將檔案存入 shoplist/01.csv

use strict;
use warnings;
use File::Basename;

my $csv_dir      = 'csv';
my $shop_file    = 'Shop_711.csv';
my $shoplist_dir = 'shoplist';

mkdir $shoplist_dir unless -d $shoplist_dir;

foreach my $csv_file ( glob( sprintf( '%s/*.csv', $csv_dir ) ) ) {

    # 從完整路徑中提取檔案名稱
    my $filename      = basename($csv_file);
    my $shoplist_file = sprintf( '%s/%s', $shoplist_dir, $filename );

    open my $fh_csv,      '<:encoding(UTF-8)', $csv_file      or die "無法開啟 $csv_file: $!";
    open my $fh_shop,     '<:encoding(UTF-8)', $shop_file     or die "無法開啟 $shop_file: $!";
    open my $fh_shoplist, '>:encoding(UTF-8)', $shoplist_file or die "無法建立 $shoplist_file: $!";

    # 先輸出 Shop_711.csv 的內容
    while ( my $line = <$fh_shop> ) {
        print $fh_shoplist $line;
    }

    # 再輸出 csv 檔案的內容
    while ( my $line = <$fh_csv> ) {
        print $fh_shoplist $line;
    }

    close $fh_csv;
    close $fh_shop;
    close $fh_shoplist;

    print "已處理: Shop_711.csv + $csv_file -> $shoplist_file\n";
}

