-------------------------------------------------
-- 一般不需改动
-------------------------------------------------


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
	host = "dds-uf6a094d79173b842.mongodb.rds.aliyuncs.com",
	port = 3717,
	authdb = "admin",
	username = "root",
	password = "Qxd12345",
}

return M