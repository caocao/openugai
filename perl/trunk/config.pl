# this file can be used to overwrite the defualt configuration

use OpenUGAI::Global;

my $base_url = "http://10.0.0.82:8009/perl/trunk";
my $base_path = "/srv/www/openugai";

# grid services
$OpenUGAI::Global::USER_SERVER_URL = $base_url . "/user.cgi";
$OpenUGAI::Global::GRID_SERVER_URL = $base_url . "/grid.cgi";
$OpenUGAI::Global::ASSET_SERVER_URL = $base_url . "/asset.cgi";
$OpenUGAI::Global::INVENTORY_SERVER_URL = $base_url . "/inventory.cgi";

# log files
$OpenUGAI::Global::LOGDIR = $base_path . "/logs";
$OpenUGAI::Global::TMPLDIR = $base_path . "/perl/trunk/template";
$OpenUGAI::Global::LOGINKEYDIR = $base_path . "/perl/trunk/loginkey";

# db settings
$OpenUGAI::Global::DSN = "dbi:mysql:openugai;host=10.0.0.83;";
$OpenUGAI::Global::DBUSER = "opensim";
$OpenUGAI::Global::DBPASS = "opensim";

# ##########
$OpenUGAI::Global::AssetStorage = "mysql";

1;

