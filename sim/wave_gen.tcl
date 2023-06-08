call {$fsdbDumpfile("./mc_top_tb.fsdb")}
call {$fsdbDumpvars(0, mc_top_tb, "+all")}
call {$fsdbDumpMDA}

run
