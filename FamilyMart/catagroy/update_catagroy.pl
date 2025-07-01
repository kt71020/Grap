#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use MyDB;
use Text::CSV;

use open qw(:std :encoding(UTF-8));

# 確保 STDOUT 正確輸出 UTF-8
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

print "=== FamilyMart 商品分類代碼更新程序 ===\n";
print "開始時間: " . localtime() . "\n\n";

# 連接資料庫
my $dbh = MyDB::connect_to_db();
eval {
    $dbh->{AutoCommit} = 0;    # 開始事務

    print "步驟 1: 重置所有 hq_org_no=1964 店鋪的 category_code 200/300 為 inactive\n";
    reset_all_categories($dbh);

    print "步驟 2: 讀取 Family_catagory.csv 並更新特定店鋪\n";
    process_category_csv($dbh);

    $dbh->commit();            # 提交事務
    print "\n=== 程序執行完成 ===\n";
    print "結束時間: " . localtime() . "\n";

} or do {
    my $error = $@ || "未知錯誤";
    print STDERR "錯誤發生: $error\n";
    print STDERR "執行回滾操作...\n";
    eval { $dbh->rollback(); };
    exit 1;
};

$dbh->disconnect();

# 函數：重置所有 hq_org_no=1964 店鋪的分類狀態
sub reset_all_categories {
    my ($dbh) = @_;

    # 取得所有 hq_org_no=1964 的店鋪 ID
    my $sql = "SELECT sid FROM shop WHERE hq_org_no = 1964";
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my @sid_list;
    while ( my $row = $sth->fetchrow_hashref() ) {
        push @sid_list, $row->{sid};
    }

    print "找到 " . scalar(@sid_list) . " 個 FamilyMart 店鋪\n";

    # 更新 category_code 200 和 300 為 inactive
    my $update_sql = "UPDATE category SET category_active = false WHERE sid = ? AND category_code IN (200, 300)";
    my $update_sth = $dbh->prepare($update_sql);

    my $updated_count = 0;
    for my $sid (@sid_list) {
        my $rows = $update_sth->execute($sid);
        $updated_count += $rows;
    }

    print "重置了 $updated_count 個分類記錄為 inactive\n\n";
}

# 函數：處理 CSV 文件並更新資料庫
sub process_category_csv {
    my ($dbh) = @_;

    my $csv_file = "$FindBin::Bin/Family_catagory.csv";

    unless ( -f $csv_file ) {
        die "找不到 CSV 文件: $csv_file\n";
    }

    # 開啟 CSV 文件
    open my $fh, '<:encoding(UTF-8)', $csv_file or die "無法開啟 CSV 文件: $!";

    my $csv = Text::CSV->new(
        {
            binary    => 1,
            auto_diag => 1,
            sep_char  => ',',
        }
    );

    # 讀取標題行
    my $header = $csv->getline($fh);
    die "無法讀取 CSV 標題行" unless $header;

    print "CSV 標題行: " . join( ", ", @$header ) . "\n";

    # 準備 SQL 語句
    my $find_shop_sql = "SELECT sid, introduction FROM shop WHERE name = ? AND hq_org_no = 1964";
    my $find_shop_sth = $dbh->prepare($find_shop_sql);

    my $update_category_sql = "UPDATE category SET category_active = true WHERE sid = ? AND category_code = ?";
    my $update_category_sth = $dbh->prepare($update_category_sql);

    my $update_intro_sql = "UPDATE shop SET introduction = ? WHERE sid = ?";
    my $update_intro_sth = $dbh->prepare($update_intro_sql);

    my $processed_count   = 0;
    my $matched_count     = 0;
    my $updated_200_count = 0;
    my $updated_300_count = 0;

    # 逐行處理 CSV
    while ( my $row = $csv->getline($fh) ) {
        my ( $name, $address, $lite, $c200, $c300 ) = @$row;

        $processed_count++;

        # 跳過沒有 c-200 或 c-300 標記的店鋪
        next unless ( defined $c200 && $c200 eq '1' ) || ( defined $c300 && $c300 eq '1' );

        # 建構店名
        my $shop_name = "FamilyMart 全家" . $name;

        # 搜尋店鋪
        $find_shop_sth->execute($shop_name);
        my $shop_row = $find_shop_sth->fetchrow_hashref();

        unless ($shop_row) {
            print "警告: 找不到店鋪: $shop_name\n";
            next;
        }

        my $sid           = $shop_row->{sid};
        my $current_intro = $shop_row->{introduction} || '';
        my $new_intro     = $current_intro;

        $matched_count++;
        print "處理店鋪: $shop_name (SID: $sid)\n";

        # 處理 c-200=1 的情況
        if ( defined $c200 && $c200 eq '1' ) {
            $update_category_sth->execute( $sid, 200 );
            $updated_200_count++;

            # 添加「仿手沖單品」到介紹中（如果還沒有的話）
            unless ( $new_intro =~ /「仿手沖單品」/ ) {
                $new_intro .= ' 「仿手沖單品」';
            }
            print "  - 啟用 category_code 200 (仿手沖單品)\n";
        }

        # 處理 c-300=1 的情況
        if ( defined $c300 && $c300 eq '1' ) {
            $update_category_sth->execute( $sid, 300 );
            $updated_300_count++;

            # 添加「義式單品」到介紹中（如果還沒有的話）
            unless ( $new_intro =~ /「義式單品」/ ) {
                $new_intro .= ' 「義式單品」';
            }
            print "  - 啟用 category_code 300 (義式單品)\n";
        }

        # 更新介紹文字（如果有變化）
        if ( $new_intro ne $current_intro ) {
            $update_intro_sth->execute( $new_intro, $sid );
            print "  - 更新介紹文字: $new_intro\n";
        }

        print "\n";
    }

    close $fh;

    print "=== 處理統計 ===\n";
    print "CSV 總行數: $processed_count\n";
    print "匹配的店鋪數: $matched_count\n";
    print "啟用 category_code 200 的店鋪數: $updated_200_count\n";
    print "啟用 category_code 300 的店鋪數: $updated_300_count\n";
}
