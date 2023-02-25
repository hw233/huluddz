-------------------------------------------------
-- 一般不需改动
-------------------------------------------------
------------------test1 专用文件

local M = {}


M.server_name = 'xyserver_dev'

M.max_client = 100000

-- 阿里短信服务
M.accessKeyId = 'LTAIEOUAF0mN8pmi'
M.accessKeySecret = 'G2ictyP5ay14YNYtPDqYkzrZg7WUTw'
M.signName = '迅游科技'
M.templateCode = 'SMS_153327702' -- 短信验证

-- 阿里OSS
M.ossAccessKey = "LTAIWkkMN8oVvEwI"
M.ossSecretKey = "ZlV0Zy5qfUnss5rwB7izoOdbTZNX6t"
M.ossEndpoint = "oss-cn-qingdao-internal.aliyuncs.com"
-- oss-cn-qingdao.aliyuncs.com
-- oss-cn-qingdao-internal.aliyuncs.com

-- 传奇来了
M.cqll_appKey = "QNK7DK2778E188QG5BDY47N79E634003"
M.cqll_appSecret = "5B24AFEA29119B3F47A847789454505A"
-- 文档示例演示 appid 和 secret
-- M.tyby_appKey = "1RNM29IW49EQYS65X6162DH8LQP4A9J3"
-- M.tyby_appSecret = "1AF4EF1A3D6AA1AA3025816169D55CDD"
-- 纵剑仙界
M.zjxj_appKey = "8A671E1B10532D6042844E5AA91FB6FF"
M.zjxj_appSecret = "3E7C6148B3EAC5082C9160F9C419354B"
-- 途游捕鱼
M.tyby_appKey = "A5FF70B606A7A93869851C4E871267BC"
M.tyby_appSecret = "AEBE7D61F09681C05DB684930691F72A"

M.cqll_usefulLife = 7200 -- token 有效时间（单位：秒）

-- 请求解散,超时时间(秒)
M.outtime = 60

-- 注册送房卡
M.USER_INIT_CARD_NUM = 0

-- 注册送金币
M.USER_INIT_GOLD_NUM = 300000

-- 玩家注册id 起始值
M.USER_START_ID = 100000
M.TOURIST_MAX_ID = 99999

M.videos_path = '/home/windy/work/file/Videos/'

-- 服务器配置存储数据库配置
M.DB_CONF = {
	name = "hlddz_conf",
	host = "8.136.209.81",
	port = 27017,
	authdb = "hlddz_conf",
	username = "xydbroot",
	password = "xunyou@root_0319", 
}

-- 如果配置了这个，在 load_gameconf.lua 中会在加载 DB 上的配置后会用这份配置覆盖从 DB 上获取的配置
M.gameConfig = {
    --["gameid"]="hlddz2021",
    ["debug_console_port"]=18100,
    ["logind_port"]=18101,
    ["gates"]={
        ["gate_port_num"]=1,
        ["gate_port1"]=18111,    
    },
    ["http_server_port"]=18108,
    ["http_server2_port"]=18109,
    httpClientPort = 18110,
    ["pub_server_url"]="http:47.105.195.185:11008",
    ["apple_err_url"]="http://game.jytx123.cn",

    ["http_server_ali_port"]=18112,
    ["http_server_third_plat"]=18113,
    ["hs_center_port"]=18114,
    ["hs_apple_port"]=18115,
    ["hs_data_collector_port"]=18117,
    ["is_logind_server"]=true,
    ["is_agent_server"]=true,
    ["cluster_open"]="agent_mgr-room-agent1-matching_mgr-d_huan_shop_mgr-pai_hang_mgr-logind",
    ["agents"]={
        ["agent_num"]=1,
        ["agent_ip1"]="0.0.0.0:13001",
     
    },
    ["node"]="main",
    ["main_node_host"]="127.0.0.1",
    dbConnectNum = 3,--mgr中的db连接数
    ["dbs"]={
        ["main"]={
            {
                ["name"]="tytest1",
                ["host"]="8.136.209.81",
                ["port"]=27017,
                ["authdb"]="admin",
                ["username"]="root",
                ["password"]="1r2o3o4t56"
            }
        },
        ["rec"]={
            {
                ["name"]="tytest1_rec",
                ["host"]="8.136.209.81",
                ["port"]=27017,
                ["authdb"]="admin",
                ["username"]="root",
                ["password"]="1r2o3o4t56"
            }
        }
    },
}

return M