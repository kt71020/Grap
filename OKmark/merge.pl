# 目標城市與輸出
my $CSV_FILE = 'ShopList.csv';
my $CSV_DIR  = 'csv';

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

open my $fh, '>:encoding(UTF-8)', $CSV_FILE or die "Cannot open $CSV_FILE: $!";

foreach my $city_code ( sort keys %city_map ) {
    my $csv_file = sprintf "%s/%s.csv", $CSV_DIR, $city_code;

    # 讀取 $csv_file 內容，除了第一行外，將其他所有內容寫入 $fh
    my $city_name = $city_map{$city_code};
    open my $fh2, '<:encoding(UTF-8)', $csv_file or die "Cannot open $csv_file: $!";
    my $header = <$fh2>;    # 讀取並跳過標題行
    while ( my $line = <$fh2> ) {
        print $fh $line;
    }
    close $fh2;
}

close $fh;
