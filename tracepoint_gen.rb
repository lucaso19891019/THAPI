arg_count = ARGV[0].to_i

puts <<EOF
/*
 * TP_ARGS takes tuples of type, argument separated by a comma.
 * It can take up to #{arg_count} tuples (which means that less than 12 tuples is
 * fine too).
 * Each tuple is also separated by a comma.
 */
#define __TP_COMBINE_TOKENS(_tokena, _tokenb)				\
		_tokena##_tokenb
#define _TP_COMBINE_TOKENS(_tokena, _tokenb)				\
		__TP_COMBINE_TOKENS(_tokena, _tokenb)
#define __TP_COMBINE_TOKENS3(_tokena, _tokenb, _tokenc)			\
		_tokena##_tokenb##_tokenc
#define _TP_COMBINE_TOKENS3(_tokena, _tokenb, _tokenc)			\
		__TP_COMBINE_TOKENS3(_tokena, _tokenb, _tokenc)
#define __TP_COMBINE_TOKENS4(_tokena, _tokenb, _tokenc, _tokend)	\
		_tokena##_tokenb##_tokenc##_tokend
#define _TP_COMBINE_TOKENS4(_tokena, _tokenb, _tokenc, _tokend)		\
		__TP_COMBINE_TOKENS4(_tokena, _tokenb, _tokenc, _tokend)

/*
 * _TP_EXVAR* extract the var names.
 * _TP_EXVAR1 and _TP_EXDATA_VAR1 are needed for -std=c99.
 */
#define _TP_EXVAR0()
#define _TP_EXVAR1(p_0_0)
EOF

arg_list = lambda { |c|
  c.times.collect { |j|
    "p_#{j}_0,p_#{j}_1"
  }.join(",")
}

second_arg_list = lambda { |c|
  c.times.collect { |j|
    "p_#{j}_1"
  }.join(",")
}

tuple_arg_list = lambda { |c|
  c.times.collect { |j|
    "p_#{j}_0 p_#{j}_1"
  }.join(",")
}

arg_count.times { |i|
  c = (i+1)
  puts "#define _TP_EXVAR#{c*2}(#{arg_list.call(c)}) #{second_arg_list.call(c)}"
}

puts <<EOF

#define _TP_EXDATA_VAR0() __tp_data
#define _TP_EXDATA_VAR1(p_0_0) __tp_data
EOF

arg_count.times { |i|
  c = (i+1)
  puts "#define _TP_EXDATA_VAR#{c*2}(#{arg_list.call(c)}) __tp_data,#{second_arg_list.call(c)}"
}

puts <<EOF

/*
 * _TP_EXPROTO* extract tuples of type, var.
 * _TP_EXPROTO1 and _TP_EXDATA_PROTO1 are needed for -std=c99.
 */
#define _TP_EXPROTO0() void
#define _TP_EXPROTO1(p_0_0) void
EOF

arg_count.times { |i|
  c = (i+1)
  puts "#define _TP_EXPROTO#{c*2}(#{arg_list.call(c)}) #{tuple_arg_list.call(c)}"
}

puts <<EOF

#define _TP_EXDATA_PROTO0() void *__tp_data
#define _TP_EXDATA_PROTO1(p_0_0) void *__tp_data
EOF

arg_count.times { |i|
  c = (i+1)
  puts "#define _TP_EXDATA_PROTO#{c*2}(#{arg_list.call(c)}) void *__tp_data,#{tuple_arg_list.call(c)}"
}

puts <<EOF
/* Preprocessor trick to count arguments. Inspired from sdt.h. */
#define _TP_NARGS(...)                  __TP_NARGS(__VA_ARGS__, #{(arg_count*2+1).times.collect(&:to_s).reverse.join(",")})
#define __TP_NARGS(#{(arg_count*2+1).times.collect{|i| "_"+i.to_s}.join(",")}, N, ...)	N
#define _TP_PROTO_N(N, ...)		_TP_PARAMS(_TP_COMBINE_TOKENS(_TP_EXPROTO, N)(__VA_ARGS__))
#define _TP_VAR_N(N, ...)		_TP_PARAMS(_TP_COMBINE_TOKENS(_TP_EXVAR, N)(__VA_ARGS__))
#define _TP_DATA_PROTO_N(N, ...)	_TP_PARAMS(_TP_COMBINE_TOKENS(_TP_EXDATA_PROTO, N)(__VA_ARGS__))
#define _TP_DATA_VAR_N(N, ...)		_TP_PARAMS(_TP_COMBINE_TOKENS(_TP_EXDATA_VAR, N)(__VA_ARGS__))
#define _TP_ARGS_PROTO(...)		_TP_PROTO_N(_TP_NARGS(0, ##__VA_ARGS__), ##__VA_ARGS__)
#define _TP_ARGS_VAR(...)		_TP_VAR_N(_TP_NARGS(0, ##__VA_ARGS__), ##__VA_ARGS__)
#define _TP_ARGS_DATA_PROTO(...)	_TP_DATA_PROTO_N(_TP_NARGS(0, ##__VA_ARGS__), ##__VA_ARGS__)
#define _TP_ARGS_DATA_VAR(...)		_TP_DATA_VAR_N(_TP_NARGS(0, ##__VA_ARGS__), ##__VA_ARGS__)
#define _TP_PARAMS(...)			__VA_ARGS__

EOF