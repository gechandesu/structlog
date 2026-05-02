import structlog

struct Simple {
	foo int
	bar string
}

fn test_struct_adapter() {
	assert structlog.struct_adapter(Simple{10, 'fooo'}) == [
		structlog.Field{'foo', 10},
		structlog.Field{'bar', 'fooo'},
	]
}

/* FIXME
enum SomeEnum {
	one
	two
	three
}

struct WithEnum {
	foo       int
	bar       string
	some_enum SomeEnum
}

fn test_struct_adapter_with_enum() {
	assert structlog.struct_adapter(WithEnum{10, 'fooo', .two}) == [
		structlog.Field{'foo', 10},
		structlog.Field{'bar', 'fooo'},
		structlog.Field{'some_enum', 'two'},
	]
}
*/
