#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

# 確保 UTF-8 輸出
binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";

use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Request::Common qw(GET POST);
use HTML::TreeBuilder::XPath;
use URI::Escape qw(uri_escape_utf8);
use Encode      qw(decode encode_utf8);

# 城市列表（根據 HiLife 網站結構）
my @cities = qw(
  台北市 基隆市 新北市 宜蘭縣 新竹縣 桃園市 苗栗縣 台中市
  彰化縣 南投縣 嘉義縣 雲林縣 台南市 高雄市 屏東縣 新竹市 嘉義市
);

# 測試模式：只抓取部分城市
@cities = qw(台北市 台中市);

# 初始化 HTTP 客戶端
my $ua = LWP::UserAgent->new(
    agent =>
'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    cookie_jar => HTTP::Cookies->new,
    timeout    => 30,
);
$ua->requests_redirectable( [ 'GET', 'HEAD' ] );

# 設定額外的 HTTP 標頭
$ua->default_header( 'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' );
$ua->default_header( 'Accept-Language'           => 'zh-TW,zh;q=0.9,en;q=0.8' );
$ua->default_header( 'Accept-Encoding'           => 'gzip, deflate, br' );
$ua->default_header( 'DNT'                       => '1' );
$ua->default_header( 'Connection'                => 'keep-alive' );
$ua->default_header( 'Upgrade-Insecure-Requests' => '1' );

# 常數
my $BASE_URL = 'https://www.hilife.com.tw/storeInquiry_street.aspx';

# 建立輸出目錄
my $csv_dir = 'csv';
mkdir $csv_dir unless -d $csv_dir;

print "開始爬取 HiLife 萊爾富門市資訊...\n";
print "目標網站: $BASE_URL\n";
print "=" x 60 . "\n";

# 遍歷每個城市
for my $city_name (@cities) {
    print "處理城市: $city_name...\n";

    # 準備 CSV 檔案
    my $safe_city_name = $city_name;
    $safe_city_name =~ s/[縣市]//g;    # 移除縣市字樣作為檔名
    my $csv_file = "$csv_dir/$safe_city_name.csv";

    open my $fh_csv, '>:encoding(UTF-8)', $csv_file or die "無法開啟 $csv_file: $!";
    print $fh_csv "name,phone,city,region,detailed_address,latitude,longitude\n";

    my $total_stores = 0;

    # 獲取該城市的門市資料
    my $stores_data = get_city_stores($city_name);

    foreach my $store (@$stores_data) {

        # 處理店名
        my $formatted_name = "HiLife " . $store->{name};

        # 處理電話格式
        my $formatted_phone = format_phone( $store->{phone} );

        # 解析地址獲取地區和詳細地址
        my ( $region, $detailed_address ) = parse_address( $store->{address}, $city_name );

        # HiLife 網站沒有提供經緯度
        my $latitude  = '';
        my $longitude = '';

        # 寫入 CSV
        my $csv_line = join( ',',
            quote_csv($formatted_name),
            quote_csv($formatted_phone),
            quote_csv($city_name), quote_csv($region), quote_csv($detailed_address),
            $latitude, $longitude );

        print $fh_csv $csv_line . "\n";
        $total_stores++;

        print "    $formatted_name - $formatted_phone - $detailed_address\n";
    }

    close $fh_csv;
    print "  $city_name 完成，共抓取 $total_stores 個門市，儲存至 $csv_file\n";

    # 城市間的延遲
    sleep 5;
}

print "\nHiLife 萊爾富門市資訊爬取完成！\n";

# 獲取指定城市的門市資料
sub get_city_stores {
    my ($city_name) = @_;
    my @stores;

    # 首先訪問主頁面
    print "    正在訪問: $BASE_URL\n";
    my $res = $ua->get($BASE_URL);
    if ( !$res->is_success ) {
        warn "無法訪問主頁面: " . $res->status_line;
        print "    回應內容: " . substr( $res->content, 0, 200 ) . "...\n" if $res->content;
        return \@stores;
    }
    print "    成功獲取主頁面，內容長度: " . length( $res->content ) . " 字元\n";

    # 解析頁面獲取表單資訊
    my $html = decode( 'utf8', $res->content );
    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse($html);
    $tree->eof;

    # 查找 ViewState 等表單參數
    my $viewstate      = '';
    my $viewstate_node = $tree->findnodes('//input[@name="__VIEWSTATE"]')->[0];
    if ($viewstate_node) {
        $viewstate = $viewstate_node->attr('value') || '';
    }

    my $eventvalidation      = '';
    my $eventvalidation_node = $tree->findnodes('//input[@name="__EVENTVALIDATION"]')->[0];
    if ($eventvalidation_node) {
        $eventvalidation = $eventvalidation_node->attr('value') || '';
    }

    $tree->delete;

    # 嘗試找到更多隱藏欄位
    my $viewstategenerator      = '';
    my $viewstategenerator_node = $tree->findnodes('//input[@name="__VIEWSTATEGENERATOR"]')->[0];
    if ($viewstategenerator_node) {
        $viewstategenerator = $viewstategenerator_node->attr('value') || '';
    }

    my $eventtarget = '';
    my $eventarg    = '';

    # 準備 POST 請求參數 - 嘗試多種可能的參數組合
    my %form_data = (
        '__VIEWSTATE'                       => $viewstate,
        '__EVENTVALIDATION'                 => $eventvalidation,
        '__VIEWSTATEGENERATOR'              => $viewstategenerator,
        '__EVENTTARGET'                     => $eventtarget,
        '__EVENTARGUMENT'                   => $eventarg,
        'city'                              => $city_name,            # 嘗試 city
        'ddlCity'                           => $city_name,            # 嘗試 ddlCity
        'ctl00$ContentPlaceHolder1$ddlCity' => $city_name,            # 嘗試完整控制項名稱
        'Submit'                            => '查詢',
        'Button1'                           => '查詢',
        'btnSearch'                         => '查詢',
    );

    # 移除空值參數
    for my $key ( keys %form_data ) {
        delete $form_data{$key} if !defined $form_data{$key} || $form_data{$key} eq '';
    }

    print "    表單參數: "
      . join( ', ', map { "$_=" . substr( $form_data{$_}, 0, 20 ) . "..." } sort keys %form_data ) . "\n";

    # 發送 POST 請求
    print "    正在發送 POST 請求查詢 $city_name...\n";
    $res = $ua->post( $BASE_URL, \%form_data );
    if ( !$res->is_success ) {
        warn "POST 請求失敗: " . $res->status_line;
        print "    回應內容: " . substr( $res->content, 0, 200 ) . "...\n" if $res->content;
        return \@stores;
    }
    print "    POST 請求成功，回應長度: " . length( $res->content ) . " 字元\n";

    $html = decode( 'utf8', $res->content );
    $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse($html);
    $tree->eof;

    # 保存 POST 回應內容用於調試
    if ( $city_name eq '台北市' ) {
        open my $debug_fh, '>:encoding(UTF-8)', 'debug_post_response.html' or warn "無法保存調試檔案: $!";
        print $debug_fh $html if $debug_fh;
        close $debug_fh       if $debug_fh;
        print "    調試: POST 回應已保存至 debug_post_response.html\n";
    }

    # 解析門市資料表格
    my @rows = $tree->findnodes('//table//tr[td]');
    print "    找到表格行數: " . scalar(@rows) . "\n";

    # 如果沒有找到表格行，嘗試其他方式尋找資料
    if ( @rows == 0 ) {
        print "    未找到表格資料，嘗試其他選擇器...\n";

        # 嘗試不同的選擇器
        my @alt_rows1 = $tree->findnodes('//tr[td]');
        print "    嘗試 //tr[td]: 找到 " . scalar(@alt_rows1) . " 行\n";

        my @alt_rows2 = $tree->findnodes('//table/tbody/tr');
        print "    嘗試 //table/tbody/tr: 找到 " . scalar(@alt_rows2) . " 行\n";

        my @all_tables = $tree->findnodes('//table');
        print "    找到表格總數: " . scalar(@all_tables) . "\n";

        # 如果找到表格，列印前幾個表格的結構
        my $max_tables = @all_tables > 3 ? 2 : $#all_tables;
        for my $i ( 0 .. $max_tables ) {
            my $table      = $all_tables[$i];
            my $table_text = substr( $table->as_HTML, 0, 200 );
            print "    表格 $i 結構: $table_text...\n";
        }

        @rows = @alt_rows1 if @alt_rows1 > @rows;
    }

    foreach my $row (@rows) {
        my @cells = $row->findnodes('./td');
        next if @cells < 3;

        my $store_id   = '';
        my $store_name = '';
        my $address    = '';
        my $phone      = '';

        if ( @cells >= 4 ) {
            $store_id   = trim( $cells[0]->as_text );
            $store_name = trim( $cells[1]->as_text );
            $address    = trim( $cells[2]->as_text );
            $phone      = trim( $cells[3]->as_text );
        }
        elsif ( @cells == 3 ) {
            $store_name = trim( $cells[0]->as_text );
            $address    = trim( $cells[1]->as_text );
            $phone      = trim( $cells[2]->as_text );
        }

        # 清理地址中的 Google Maps 連結
        $address =~ s/\s*\[.*?\]\s*//g;

        next unless $store_name && $address && $phone;

        push @stores,
          {
            id      => $store_id,
            name    => $store_name,
            address => $address,
            phone   => $phone,
          };
    }

    $tree->delete;
    return \@stores;
}

# 解析地址獲取地區和詳細地址
sub parse_address {
    my ( $address, $city_name ) = @_;

    # 移除郵遞區號和城市名稱
    $address =~ s/^\d{3}//;             # 移除郵遞區號
    $address =~ s/^\Q$city_name\E//;    # 移除城市名稱

    # 提取地區名稱（通常是前幾個字加上區、鄉、鎮、市）
    my $region = '';
    if ( $address =~ /^([^區鄉鎮市]*[區鄉鎮市])(.*)/ ) {
        $region = $1;
        my $detailed_address = $2;
        return ( $region, $detailed_address );
    }

    # 如果無法解析，返回原始地址
    return ( '', $address );
}

# 輔助函數：清理文字
sub trim {
    my $text = shift;
    return '' unless defined $text;
    $text =~ s/^\s+|\s+$//g;
    return $text;
}

# 輔助函數：格式化電話號碼
sub format_phone {
    my $phone = shift;
    return $phone unless $phone;

    # 移除所有非數字字符
    ( my $digits = $phone ) =~ s/\D//g;

    # 台灣電話號碼格式化
    if ( $digits =~ /^(\d{2})(\d{4})(\d{4})$/ ) {
        return "$1-$2-$3";    # 10位數：XX-XXXX-XXXX
    }
    elsif ( $digits =~ /^(\d{2})(\d{7})$/ ) {
        return "$1-$2";       # 9位數：XX-XXXXXXX
    }
    elsif ( $digits =~ /^(\d{3})(\d{3})(\d{4})$/ ) {
        return "$1-$2-$3";    # 手機號碼：XXX-XXX-XXXX
    }

    return $phone;            # 無法格式化時返回原始號碼
}

# 輔助函數：CSV 引號處理
sub quote_csv {
    my $text = shift;
    return '' unless defined $text;

    # 如果包含逗號、引號或換行符，需要用引號包圍
    if ( $text =~ /[,"\n\r]/ ) {
        $text =~ s/"/""/g;    # 雙引號轉義
        return "\"$text\"";
    }

    return $text;
}
