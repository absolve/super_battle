class_name Boss
extends Enemy
## Boss 占位脚本：**行为还没设计**（M8 / feature_design §6.1），本脚本只当一个类型锚点用。
##
## 有了它，Boss 关、测试场与后续的「阶段 / 弱点 / 空投节奏」逻辑都能用 `is Boss` 判类型，
## 不必到处猜 `enemyId` 字符串；数值（血量 / 体型 / 护甲）目前全写在 `scene/enemy/boss.tscn`
## 的 Inspector 里，照 code_design §6.3「能进 Inspector 的不写进代码」。
##
## 真做 Boss 时在本脚本里覆盖 [method Enemy] 的行为（多阶段、打不到的窗口、定期空投），
## 并把血量口径按人数乘数（1 / 1.8 / 2.5 / 3.2，level_design §4）在运行时算出来。
