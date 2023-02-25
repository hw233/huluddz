-- type 1: 开局触发
-- type 2: 每回合触发
-- type 3: 其他

local skills = {
	-- {id = 1, name = "画地为牢", desc = "降低其他技能的2%触发概率", type = 1},
	-- {id = 2, name = "抢夺", desc = "抢夺胡牌玩家5%的豆子", type = 3},
	{id = 3, name = "天眼", desc = "七雀牌模式下可以看到当前牌堆最上方的一张牌是什么牌", type = 2, prob = 20},
	{id = 4, name = "幸运成对", desc = "七雀牌模式下增加摸到多个对子的概率", type = 1, prob = 20},
	{id = 5, name = "兄弟同心", desc = "增加摸到连对的概率", type = 1, prob = 20},
	{id = 6, name = "四星连珠", desc = "七雀牌模式下增加摸到同样四张牌的概率", type = 1, prob = 20},
	{id = 7, name = "起手4同花", type = 1, prob = 20},
	-- {id = 8, name = "火眼金睛", desc = "所有模式触发，开局触发可以看到下家手牌2秒钟", type = 3, prob = 20},
	{id = 9, name = "起手一张花", desc = "起手一张花", type = 1, prob = 20},
	{id = 10, name = "癞子王", desc = "起手一张王", type = 1, prob = 20},
	{id = 11, name = "起手清一色", desc = "起手清一色", type = 1, prob = 20},
	{id = 12, name = "天下第一", desc = "增加首出的概率", type = 3, prob = 20},
	
}








return skills