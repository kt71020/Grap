#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
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
my $API_URL             = "http://127.0.0.1:5120/api/v1/upload/add_shop";
my $csv_file;
my $auth_token;
my $config_file = $DEFAULT_CONFIG_FILE;
my $help;
my $verbose;

# 解析命令行參數
GetOptions(
    'file|f=s'   => \$csv_file,
    'auth|a=s'   => \$auth_token,
    'config|c=s' => \$config_file,
    'url|u=s'    => \$API_URL,
    'verbose|v'  => \$verbose,
    'help|h'     => \$help,
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
    timeout => 300,
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

print "發送請求中...\n" if $verbose;

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

    if ( $result->{status} ) {
        print "✅ " . ( $result->{message} || "上傳成功" ) . "\n\n";

        # 顯示詳細資訊
        if ( $result->{upload_shop} ) {
            my $shop_info = $result->{upload_shop};
            print "詳細資訊：\n";
            print "  商店 ID：" . ( $shop_info->{sid} || "未知" ) . "\n";
            print "  狀態：" .    ( $shop_info->{status} ? "成功" : "失敗" ) . "\n";
            print "  訊息：" .    ( $shop_info->{message}       || "無" ) . "\n";
            print "  錯誤數：" .   ( $shop_info->{error}         || 0 ) . "\n";
            print "  分公司資料：" . ( $shop_info->{regional}      || "無" ) . "\n";
            print "  分公司筆數：" . ( $shop_info->{rows_regional} || 0 ) . "\n";

            if ( $shop_info->{regional_id_list} && @{ $shop_info->{regional_id_list} } ) {
                print "  分公司 ID 列表：" . join( ", ", @{ $shop_info->{regional_id_list} } ) . "\n";
            }
        }
    }
    else {
        print "❌ 上傳失敗：" . ( $result->{message} || "未知錯誤" ) . "\n";
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

設定檔格式 (JSON)：
    {
        "auth_token": "your-api-token-here",
        "api_url": "http://127.0.0.1:5120/api/v1/upload/add_shop"
    }

EOF
}
