#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use HTTP::Request;
use JSON;
use File::Basename;
use Getopt::Long;
use Encode qw(decode_utf8);

# 設定輸出編碼
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );

# 程式版本和說明
my $VERSION     = "1.0.2";
my $DESCRIPTION = "商店 CSV 檔案上傳程式";

# 預設設定
my $DEFAULT_CONFIG_FILE = "config.json";
my $API_URL             = "http://dev.uirapuka.com:5120/api/v1/upload/add_shop_sync";
my $csv_file;
my $auth_token;
my $config_file = $DEFAULT_CONFIG_FILE;
my $help;
my $verbose;
my $timeout       = 600;    # 預設 10 分鐘逾時
my $poll_interval = 5;      # 輪詢間隔秒數

# 解析命令行參數
GetOptions(
    'file|f=s'    => \$csv_file,
    'auth|a=s'    => \$auth_token,
    'config|c=s'  => \$config_file,
    'url|u=s'     => \$API_URL,
    'timeout|t=i' => \$timeout,
    'poll|p=i'    => \$poll_interval,
    'verbose|v'   => \$verbose,
    'help|h'      => \$help,
) or die "錯誤：無法解析命令行參數！\n";

# 顯示幫助信息
if ($help) {
    show_help();
    exit 0;
}

# 讀取設定檔
my $config = load_config($config_file);

# 設定優先權：命令行參數 > 設定檔 > 預設值
$auth_token = $auth_token || $config->{auth_token} || $ENV{API_TOKEN};
$API_URL    = $API_URL    || $config->{api_url}    || $API_URL;

# 檢查必要參數
unless ($csv_file) {
    print STDERR "錯誤：缺少 CSV 檔案參數！\n\n";
    show_help();
    exit 1;
}

unless ($auth_token) {
    print STDERR "錯誤：缺少認證 Token！\n";
    print STDERR "請透過以下方式之一提供 Token：\n";
    print STDERR "  1. 設定檔 ($config_file) 中的 auth_token 欄位\n";
    print STDERR "  2. 命令行參數 -a 或 --auth\n";
    print STDERR "  3. 環境變數 API_TOKEN\n\n";
    show_help();
    exit 1;
}

# 檢查檔案是否存在
unless ( -f $csv_file ) {
    die "錯誤：CSV 檔案 '$csv_file' 不存在！\n";
}

# 檢查檔案是否為 CSV 格式
unless ( $csv_file =~ /\.csv$/i ) {
    die "錯誤：檔案 '$csv_file' 不是 CSV 格式！\n";
}

print "開始上傳 CSV 檔案...\n"   if $verbose;
print "檔案：$csv_file\n"     if $verbose;
print "API 端點：$API_URL\n"  if $verbose;
print "設定檔：$config_file\n" if $verbose;

# 創建 HTTP 客戶端
my $ua = LWP::UserAgent->new(
    agent   => "CSV-Uploader/$VERSION",
    timeout => $timeout,
);

# 準備 HTTP 請求
my $request = POST(
    $API_URL,
    Content_Type => 'form-data',
    Content      => [
        file => [ $csv_file, basename($csv_file), 'text/csv' ]
    ]
);

# 設定 Authorization header
$request->header( 'Authorization' => $auth_token );

print "發送請求中...\n"                if $verbose;
print "⏱️  請求逾時設定：${timeout} 秒\n" if $verbose;

# 發送請求
my $response = $ua->request($request);

# 處理回應
if ( $response->is_success ) {
    my $content = $response->decoded_content;

    # 解析 JSON 回應
    my $json = JSON->new->utf8->allow_nonref;
    my $result;

    eval { $result = $json->decode($content); };

    if ($@) {
        print STDERR "警告：無法解析 JSON 回應：$@\n";
        print "原始回應：\n$content\n";
        exit 1;
    }

    # 顯示結果
    print "=" x 50 . "\n";
    print "上傳結果：\n";
    print "=" x 50 . "\n";

    # 檢查是否為處理中狀態 (假設 status = 2 表示處理中)
    if ( $result->{status} && $result->{status} == 2 ) {
        print "⏳ 資料處理中...\n";

        if ( $result->{message} ) {
            if ( ref $result->{message} eq 'ARRAY' ) {
                for my $msg ( @{ $result->{message} } ) {
                    print "  • $msg\n";
                }
            }
            else {
                print "  $result->{message}\n";
            }
        }

        # 如果有處理 ID，可以用來輪詢狀態
        my $process_id = $result->{process_id} || $result->{sid};

        if ($process_id) {
            print "  處理 ID：$process_id\n";
            print "  預估處理時間：" . ( $result->{estimated_time} || "未知" ) . "\n" if $result->{estimated_time};

            # 開始輪詢處理狀態
            my $final_result = poll_processing_status( $ua, $auth_token, $process_id );

            if ($final_result) {
                $result = $final_result;
                print "\n" . "=" x 50 . "\n";
                print "最終處理結果：\n";
                print "=" x 50 . "\n";
            }
            else {
                print "❌ 輪詢處理狀態失敗\n";
                exit 1;
            }
        }
        else {
            print "⚠️  無法取得處理 ID，無法輪詢狀態\n";
            print "請稍後手動檢查處理結果\n";
            exit 0;
        }
    }

    # 處理新的JSON格式結構
    if ( $result->{status} && $result->{status} == 1 ) {
        print "✅ 上傳成功\n";

        # 顯示基本資訊
        print "詳細資訊：\n";
        print "  商店 ID：" . ( $result->{sid} || "未知" ) . "\n";
        print "  狀態：成功\n";
        print "  錯誤數：" .   ( $result->{error}         || 0 ) . "\n";
        print "  版本：" .    ( $result->{version}       || "未知" ) . "\n";
        print "  分公司筆數：" . ( $result->{rows_regional} || 0 ) . "\n";

        # 顯示分公司 ID 列表
        if ( $result->{regional_id_list} && @{ $result->{regional_id_list} } ) {
            print "  分公司 ID 列表：" . join( ", ", @{ $result->{regional_id_list} } ) . "\n";
        }

        # 顯示處理訊息 (現在是陣列格式)
        if ( $result->{message} && ref $result->{message} eq 'ARRAY' && @{ $result->{message} } ) {
            print "\n📋 處理訊息：\n";
            for my $msg ( @{ $result->{message} } ) {
                print "  • $msg\n";
            }
        }
        elsif ( $result->{message} && ref $result->{message} ne 'ARRAY' ) {
            print "\n📋 處理訊息：$result->{message}\n";
        }

        # 顯示驗證詳情
        if ( $result->{validation_details} ) {
            my $details = $result->{validation_details};
            print "\n📊 資料統計：\n";
            print "  商店資訊筆數：" . ( $details->{shop_info_count}         || 0 ) . "\n";
            print "  商品筆數：" .   ( $details->{product_count}           || 0 ) . "\n";
            print "  分類筆數：" .   ( $details->{category_count}          || 0 ) . "\n";
            print "  選項筆數：" .   ( $details->{shop_option_count}       || 0 ) . "\n";
            print "  選項值筆數：" .  ( $details->{shop_option_value_count} || 0 ) . "\n";
            print "  分公司筆數：" .  ( $details->{regional_count}          || 0 ) . "\n";
        }

        # 顯示 CSV 內容 (如果 verbose 模式)
        if ( $verbose && $result->{csv_content_list} && @{ $result->{csv_content_list} } ) {
            print "\n📄 CSV 檔案內容：\n";
            for my $line ( @{ $result->{csv_content_list} } ) {
                print "  $line\n";
            }
        }
    }
    else {
        # 處理失敗情況
        print "❌ 上傳失敗\n";

        if ( $result->{message} ) {
            if ( ref $result->{message} eq 'ARRAY' ) {
                print "錯誤訊息：\n";
                for my $msg ( @{ $result->{message} } ) {
                    print "  • $msg\n";
                }
            }
            else {
                print "錯誤訊息：$result->{message}\n";
            }
        }

        if ( $result->{error} && $result->{error} > 0 ) {
            print "錯誤數量：" . $result->{error} . "\n";
        }

        exit 1;
    }

    if ($verbose) {
        print "\n完整回應：\n";
        print $json->pretty->encode($result);
    }

}
else {
    my $status_code = $response->code;
    my $content     = $response->decoded_content;

    print STDERR "❌ HTTP 請求失敗：\n";
    print STDERR "狀態碼：$status_code\n";
    print STDERR "錯誤訊息：" . $response->message . "\n\n";

    # 特別處理 422 CSV 格式錯誤
    if ( $status_code == 422 ) {
        print STDERR "📄 CSV 檔案格式錯誤 (422 Unprocessable Entity)\n";
        print STDERR "檔案內容經檢查後發現格式不符API規範\n\n";

        # 嘗試解析詳細錯誤訊息
        if ($content) {
            my $json = JSON->new->utf8->allow_nonref;
            eval {
                my $error_result = $json->decode($content);
                if ( $error_result && ref $error_result eq 'HASH' ) {
                    print STDERR "📋 詳細錯誤資訊：\n";

                    if ( $error_result->{message} ) {
                        print STDERR "  訊息：" . $error_result->{message} . "\n";
                    }

                    if ( $error_result->{error_details} ) {
                        my $details = $error_result->{error_details};

                        if ( $details->{error_type} ) {
                            print STDERR "  錯誤類型：" . $details->{error_type} . "\n";
                        }

                        if ( $details->{upload_info} ) {
                            my $upload_info = $details->{upload_info};
                            print STDERR "\n📊 檔案處理詳情：\n";

                            if ( $upload_info->{message} ) {
                                print STDERR "  處理訊息：" . $upload_info->{message} . "\n";
                            }

                            if ( $upload_info->{error} ) {
                                print STDERR "  具體錯誤：" . $upload_info->{error} . "\n";
                            }
                        }
                    }
                    print STDERR "\n";
                }
            };
            if ($@) {
                print STDERR "無法解析錯誤回應，顯示原始內容：\n$content\n\n";
            }
        }

        print STDERR "🔧 建議檢查項目：\n";
        print STDERR "  • CSV 檔案編碼是否為 UTF-8\n";
        print STDERR "  • 欄位分隔符號是否正確 (通常為逗號)\n";
        print STDERR "  • 必要欄位是否缺失或格式錯誤\n";
        print STDERR "  • 資料內容是否符合 API 規範\n";
        print STDERR "  • 檔案是否有非法字符或格式問題\n\n";
    }
    else {
        # 其他 HTTP 錯誤的一般處理
        if ( $verbose && $content ) {
            print STDERR "回應內容：\n$content\n";
        }
    }

    exit 1;
}

print "\n上傳完成！\n";

# 讀取設定檔函數
sub load_config {
    my ($config_path) = @_;
    my $config = {};

    # 如果設定檔不存在，回傳空設定
    unless ( -f $config_path ) {
        print "提示：設定檔 '$config_path' 不存在，使用預設設定\n" if $verbose;
        return $config;
    }

    print "載入設定檔：$config_path\n" if $verbose;

    # 讀取設定檔內容
    open my $fh, '<:utf8', $config_path or do {
        print STDERR "警告：無法讀取設定檔 '$config_path': $!\n";
        return $config;
    };

    my $content = do { local $/; <$fh> };
    close $fh;

    # 解析 JSON
    my $json = JSON->new->utf8->allow_nonref;
    eval { $config = $json->decode($content); };

    if ($@) {
        print STDERR "警告：設定檔格式錯誤：$@\n";
        print STDERR "使用預設設定繼續執行...\n";
        return {};
    }

    print "設定檔載入成功\n" if $verbose;
    return $config;
}

# 顯示幫助信息
sub show_help {
    print <<"EOF";
$DESCRIPTION v$VERSION

用法：
    perl upload_csv.pl -f <CSV檔案> [選項]

必要參數：
    -f, --file <檔案>      指定要上傳的 CSV 檔案路徑

選項參數：
    -c, --config <檔案>    指定設定檔路徑 (預設: $DEFAULT_CONFIG_FILE)
    -a, --auth <token>     API 認證 Token (覆蓋設定檔設定)
    -u, --url <URL>        指定 API 端點 (覆蓋設定檔設定)
    -t, --timeout <秒數>   HTTP 請求逾時時間 (預設: 600 秒)
    -p, --poll <秒數>      輪詢間隔時間 (預設: 5 秒)
    -v, --verbose          顯示詳細執行資訊
    -h, --help             顯示此幫助信息

認證 Token 優先權 (由高到低)：
    1. 命令行參數 (-a, --auth)
    2. 設定檔 (auth_token 欄位)
    3. 環境變數 (API_TOKEN)

範例：
    perl upload_csv.pl -f shop_data.csv
    perl upload_csv.pl -f shop_data.csv -c my_config.json -v
    perl upload_csv.pl -f shop_data.csv -a "override-token"
    perl upload_csv.pl -f shop_data.csv -t 1200 -p 10 -v
    perl upload_csv.pl -f large_shop_data.csv --timeout 1800 --poll 15

設定檔格式 (JSON)：
    {
        "auth_token": "your-api-token-here",
        "api_url": "http://127.0.0.1:5120/api/v1/upload/add_shop_sync"
    }

EOF
}

# 輪詢處理狀態函數
sub poll_processing_status {
    my ( $ua, $auth_token, $process_id ) = @_;

    # 假設有一個狀態查詢 API 端點
    my $status_url = $API_URL;
    $status_url =~ s/add_shop_sync$/status\/$process_id/;

    my $max_polls  = int( $timeout / $poll_interval );    # 最大輪詢次數
    my $poll_count = 0;

    print "開始輪詢處理狀態...\n";
    print "輪詢間隔：${poll_interval} 秒\n";
    print "最大輪詢時間：${timeout} 秒\n\n";

    while ( $poll_count < $max_polls ) {
        $poll_count++;

        print "⏱️  輪詢 #${poll_count}/${max_polls} - ";

        # 創建狀態查詢請求
        my $status_request = HTTP::Request->new( GET => $status_url );
        $status_request->header( 'Authorization' => $auth_token );

        # 發送狀態查詢請求
        my $status_response = $ua->request($status_request);

        if ( !$status_response->is_success ) {
            print "❌ 狀態查詢失敗：" . $status_response->message . "\n";
            sleep($poll_interval);
            next;
        }

        # 解析狀態回應
        my $json = JSON->new->utf8->allow_nonref;
        my $status_result;

        eval { $status_result = $json->decode( $status_response->decoded_content ); };

        if ($@) {
            print "❌ 無法解析狀態回應\n";
            sleep($poll_interval);
            next;
        }

        # 檢查處理狀態
        if ( $status_result->{status} == 1 ) {
            print "✅ 處理完成！\n";
            return $status_result;
        }
        elsif ( $status_result->{status} == 2 ) {

            # 仍在處理中
            my $progress = $status_result->{progress} || "未知";
            print "⏳ 處理中... ($progress)\n";

            if ( $status_result->{message} ) {
                if ( ref $status_result->{message} eq 'ARRAY' ) {
                    for my $msg ( @{ $status_result->{message} } ) {
                        print "     • $msg\n";
                    }
                }
                else {
                    print "     $status_result->{message}\n";
                }
            }
        }
        elsif ( $status_result->{status} == 0 ) {
            print "❌ 處理失敗\n";
            return $status_result;
        }
        else {
            print "⚠️  未知狀態：" . ( $status_result->{status} || "無" ) . "\n";
        }

        # 如果不是最後一次輪詢，則等待
        if ( $poll_count < $max_polls ) {
            sleep($poll_interval);
        }
    }

    print "⏰ 輪詢逾時，處理可能仍在進行中\n";
    print "請稍後手動檢查處理結果\n";
    return undef;
}
