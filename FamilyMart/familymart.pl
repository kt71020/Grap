#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

# 確保 STDOUT 正確輸出 UTF-8
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

use LWP::UserAgent;
use HTTP::Cookies;
use JSON;
use URI::Escape qw(uri_escape_utf8);
use Encode      qw(encode_utf8);

# API 設定
my $KEY     = '6F30E8BF706D653965BDE302661D1241F8BE9EBC';
my $API_URL = 'https://api.map.com.tw/net/familyShop.aspx';

# 目標城市與輸出
my $CITY_NAME    = '台北市';
my $CSV_DIR      = 'csv';
my $CSV_FILENAME = 'FamilyMart';

# 城市代碼對照表 (code => name)
my %city_map = (
    '02' => '基隆市',
    '01' => '台北市',
    '03' => '新北市',
    '04' => '桃園市',
    '05' => '新竹市',
    '06' => '新竹縣',
    '07' => '苗栗縣',
    '08' => '台中市',
    '10' => '彰化縣',
    '11' => '南投縣',
    '12' => '雲林縣',
    '14' => '嘉義縣',
    '13' => '嘉義市',
    '15' => '台南市',
    '17' => '高雄市',
    '19' => '屏東縣',
    '20' => '宜蘭縣',
    '21' => '花蓮縣',
    '22' => '台東縣',
    '24' => '連江縣',
    '25' => '金門縣',
    '23' => '澎湖縣',
);
mkdir $CSV_DIR unless -d $CSV_DIR;

# 遍歷每個城市代碼與名稱
# my $CITY_TEST_CODE = '17';
# my $CITY_NAME2     = $city_map{$CITY_TEST_CODE};
# %city_map = ( $CITY_TEST_CODE => $CITY_NAME2 );

# %city_map = (
#     '01' => '台北市',
#     '19' => '屏東縣',
#     '20' => '宜蘭縣',
#     '21' => '花蓮縣',
#     '22' => '台東縣',
#     '24' => '連江縣',
#     '25' => '金門縣',
#     '23' => '澎湖縣',
# );

# 遍歷每個城市代碼與名稱
for my $CITY_CODE ( sort keys %city_map ) {
    my $CITY_NAME = $city_map{$CITY_CODE};
    print "Processing city $CITY_CODE: $CITY_NAME...\n";

    # 初始化 HTTP 客戶端
    my $ua = LWP::UserAgent->new(
        agent      => 'Mozilla/5.0 (Macintosh; Intel Mac OS X)',
        cookie_jar => HTTP::Cookies->new,
    );
    $ua->default_header(
        'Referer' => 'https://www.family.com.tw/',
        'Accept'  => '*/*',
        'Origin'  => 'https://www.family.com.tw',
    );

    # -----------------------------
    # Step 1: 取得鄉鎮市區列表
    # -----------------------------
    my $city_enc = uri_escape_utf8($CITY_NAME);
    my $town_url = "$API_URL?searchType=ShowTownList&type=&city=$city_enc&fun=storeTownList&key=$KEY";
    my $res      = $ua->get($town_url);
    die "GET ShowTownList failed: " . $res->status_line unless $res->is_success;

    my $raw = $res->decoded_content;

    # 抽取括號內 JSON
    my $start = index( $raw, '(' );
    my $end   = rindex( $raw, ')' );
    if ( $start == -1 || $end == -1 || $end <= $start ) {
        die "Unexpected format from ShowTownList";
    }
    my $town_json = substr( $raw, $start + 1, $end - $start - 1 );
    print "town_json: \n$town_json\n";

    # 使用字符串處理方式提取區域名稱
    my @regions;
    while ( $town_json =~ /"town"\s*:\s*"([^"]+)"/g ) {
        push @regions, $1;
    }

    # Debug
    print "Regions: ", join( ", ", @regions ), "\n";

    # -----------------------------
    # Step 2: 取得門市並輸出 CSV
    # -----------------------------
    my $csv_file = sprintf "%s/%s.csv", $CSV_DIR, $CITY_CODE;
    open my $fh, '>:encoding(UTF-8)', $csv_file or die "Cannot open $csv_file: $!";
    print $fh "name,phone,city,region,detailed_address,latitude,longitude\n";

    foreach my $region (@regions) {
        print "Processing $region...\n";
        sleep 3;
        my $area_enc = uri_escape_utf8($region);
        my $url      = sprintf( "%s?searchType=ShopList&type=&city=%s&area=%s&road=&fun=showStoreList&key=%s",
            $API_URL, $city_enc, $area_enc, $KEY );
        my $r2 = $ua->get($url);
        die "GET ShopList failed for $region: " . $r2->status_line unless $r2->is_success;
        my $raw2 = $r2->decoded_content;

        # 抽取括號內 JSON
        my $sstart = index( $raw2, '(' );
        my $send   = rindex( $raw2, ')' );
        next if $sstart == -1 || $send == -1 || $send <= $sstart;
        my $store_json = substr( $raw2, $sstart + 1, $send - $sstart - 1 );

        # 調試輸出
        # print "JSON sample: " . substr( $store_json, 0, 300 ) . "...\n";

        # 使用字符串處理方式提取店鋪資訊
        my @stores;

        # 嘗試更寬松的匹配模式
        while ( $store_json =~
/{[^{]*?"NAME"\s*:\s*"([^"]+)".*?"TEL"\s*:\s*"([^"]+)".*?"addr"\s*:\s*"([^"]+)".*?"px"\s*:([^,]+).*?"py"\s*:([^,\}]+).*?}/gs
          )
        {
            push @stores,
              {
                NAME => $1,
                TEL  => $2,
                addr => $3,
                px   => $4,
                py   => $5,
              };
        }

        my $stores_count = scalar(@stores);
        print "stores_count: $stores_count\n";

        foreach my $s (@stores) {
            my $name_raw = $s->{NAME} // '';
            my $name     = "FamilyMart $name_raw";
            my ($tel)    = split /,/, ( $s->{TEL} // '' );
            $tel =~ s/\D//g;
            my $phone;
            if ( $tel =~ /^(\d{2})(\d{4})(\d{4})\z/ ) {
                $phone = "$1-$2-$3";    # 10位數電話: XX-XXXX-XXXX
            }
            elsif ( $tel =~ /^(\d{2})(\d{7})\z/ ) {
                $phone = "$1-$2";       # 9位數電話: XX-XXXXXXX (另一種格式)
            }
            else {
                $phone = $tel;          # 其他格式保持原樣
            }

            my $addr = $s->{addr} // '';
            $addr =~ s/^\Q$CITY_NAME$region\E//;

            # 經緯度
            my $lat = $s->{py} // '';
            my $lng = $s->{px} // '';

            # 去除經緯度前後的空格
            $lat =~ s/^\s+|\s+$//g;
            $lng =~ s/^\s+|\s+$//g;
            my $str = join( ',', $name, $phone, $CITY_NAME, $region, $addr, $lat, $lng );
            print "$str\n";
            print $fh $str, "\n";
        }
    }

    close $fh;
    print "Saved to $csv_file\n";
    sleep 3;
}

# 檔名安全化
sub encode_filename {
    my $f = shift;
    $f = encode_utf8($f);
    $f =~ s{[\\/:*?"<>|]}{_}g;
    return $f;
}

__END__
