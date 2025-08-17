#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST GET);
use JSON;
use Time::HiRes qw(sleep);

# 測試設定
my $API_BASE      = "http://127.0.0.1:5120/api/v1/upload";
my $AUTH_TOKEN    = "your-api-token-here";
my $TEST_CSV_FILE = "test_large.csv";

print "🧪 CSV 上傳 API 測試工具\n";
print "=" x 50 . "\n";

# 建立測試用的大型 CSV 檔案
create_test_csv( $TEST_CSV_FILE, 200 );    # 建立 200 筆分公司資料

# 建立 HTTP 客戶端
my $ua = LWP::UserAgent->new(
    agent   => "API-Tester/1.0",
    timeout => 30
);

# 測試 1: 上傳檔案
print "📤 測試 1: 上傳大型 CSV 檔案\n";
my $upload_result = test_upload($TEST_CSV_FILE);

if ( $upload_result && $upload_result->{status} == 2 ) {
    print "✅ 檔案已進入非同步處理模式\n";
    print "🆔 處理 ID: $upload_result->{process_id}\n";
    print "📊 預估處理時間: $upload_result->{estimated_time}\n";

    # 測試 2: 輪詢狀態
    print "\n📋 測試 2: 輪詢處理狀態\n";
    my $final_result = poll_status( $upload_result->{process_id} );

    if ( $final_result && $final_result->{status} == 1 ) {
        print "✅ 處理完成！\n";
        print "🏪 商店 ID: $final_result->{sid}\n";
        print "🏢 分公司數量: $final_result->{rows_regional}\n";
        print "📋 處理訊息:\n";
        for my $msg ( @{ $final_result->{message} } ) {
            print "   • $msg\n";
        }
    }
}
else {
    print "❌ 上傳測試失敗\n";
}

# 清理測試檔案
unlink $TEST_CSV_FILE;
print "\n🧹 清理測試檔案完成\n";

#=============================================================================
# 測試函數
#=============================================================================

sub test_upload {
    my ($csv_file) = @_;

    my $request = POST(
        "$API_BASE/add_shop",
        Content_Type => 'form-data',
        Content      => [
            file => [ $csv_file, 'test.csv', 'text/csv' ]
        ]
    );

    $request->header( 'Authorization' => $AUTH_TOKEN );

    my $response = $ua->request($request);

    if ( $response->is_success ) {
        my $result = decode_json( $response->decoded_content );
        print "📤 上傳回應: " . $response->status_line . "\n";
        return $result;
    }
    else {
        print "❌ 上傳失敗: " . $response->status_line . "\n";
        print "📄 回應內容: " . $response->decoded_content . "\n";
        return;
    }
}

sub poll_status {
    my ($process_id) = @_;

    my $max_polls  = 60;    # 最多輪詢 60 次
    my $poll_count = 0;

    while ( $poll_count < $max_polls ) {
        $poll_count++;

        print "⏱️  輪詢 #$poll_count - ";

        my $request = GET("$API_BASE/status/$process_id");
        $request->header( 'Authorization' => $AUTH_TOKEN );

        my $response = $ua->request($request);

        if ( !$response->is_success ) {
            print "❌ 狀態查詢失敗: " . $response->status_line . "\n";
            sleep(2);
            next;
        }

        my $result = decode_json( $response->decoded_content );

        if ( $result->{status} == 1 ) {
            print "✅ 處理完成！\n";
            return $result;
        }
        elsif ( $result->{status} == 2 ) {
            my $progress = $result->{progress} || "未知";
            print "⏳ 處理中... ($progress)\n";

            if ( $result->{message} ) {
                for my $msg ( @{ $result->{message} } ) {
                    print "     • $msg\n";
                }
            }
        }
        elsif ( $result->{status} == 0 ) {
            print "❌ 處理失敗\n";
            if ( $result->{message} ) {
                for my $msg ( @{ $result->{message} } ) {
                    print "     • $msg\n";
                }
            }
            return $result;
        }

        sleep(3);    # 等待 3 秒再次輪詢
    }

    print "⏰ 輪詢逾時\n";
    return;
}

sub create_test_csv {
    my ( $filename, $regional_count ) = @_;

    print "📝 建立測試 CSV 檔案: $filename (包含 $regional_count 筆分公司資料)\n";

    open my $fh, '>:utf8', $filename or die "無法建立測試檔案: $!";

    # CSV 標頭和商店資訊
    print $fh <<'EOF';
---,分隔線,商店資訊---
申請編號,
公司名稱,測試大型商店
城市,臺北市
鄉鎮市區,信義區
詳細地址,信義路五段7號
電話,0227208889
介紹,測試用大型商店資料
訂購備註,
主分類,A
次分類,1
是否顯示,1
強制更新,0
版本,4
---,分隔線,商品分類代碼,---
商品分類編號,商品分類名稱
1,主餐
2,飲料
3,甜點
---,分隔線,共用選項代碼,---
選項編號,選項名稱,必選項目
1,[加料區],0
---,分隔線,共用選項價格代碼,---
選項編號,名稱,價格
1,加飯,10
1,加麵,15
---,分隔線,商品資料---
商品分類編號,選項,價格,名稱,簡單描述,詳細描述
1,1,100,測試主餐1,,
1,1,120,測試主餐2,,
2,,30,測試飲料1,,
2,,35,測試飲料2,,
3,,25,測試甜點1,,
---,分隔線,分公司基本資料,---
分公司名稱,電話,城市,鄉鎮市區,詳細地址,緯度,經度
EOF

    # 產生大量分公司資料
    for my $i ( 1 .. $regional_count ) {
        my $city =
            $i % 5 == 0 ? '高雄市'
          : $i % 4 == 0 ? '台中市'
          : $i % 3 == 0 ? '台南市'
          : $i % 2 == 0 ? '新北市'
          :               '台北市';

        my $district = sprintf( "測試區%03d", $i % 100 );
        my $phone    = sprintf( "02%08d",  20000000 + $i );
        my $address  = sprintf( "測試路%d號",  $i );
        my $lat      = sprintf( "%.6f",    25.0 + ( $i % 100 ) * 0.001 );
        my $lng      = sprintf( "%.6f",    121.5 + ( $i % 100 ) * 0.001 );

        print $fh "測試分店$i,$phone,$city,$district,$address,$lat,$lng\n";
    }

    close $fh;
    print "✅ 測試檔案建立完成\n";
}
