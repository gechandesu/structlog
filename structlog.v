module structlog

import io
import os
import strings
import time
import term
import x.json2 as json

pub interface RecordHandler {
mut:
	// handle method must prepare the Record for writing and write it.
	handle(rec Record) !
}

pub enum Level {
	none  // disables all logs.
	fatal // disables error, warn, info, debug and trace.
	error // disables warn, info, debug and trace.
	warn  // disables info, debug and trace.
	info  // disables debug and trace.
	debug // disables trace.
	trace
}

pub type Value = i8
	| i16
	| i32
	| i64
	| int
	| isize
	| u8
	| u16
	| u32
	| u64
	| usize
	| f32
	| f64
	| string
	| bool
	| []Value
	| map[string]Value

// str returns a string representation of Value.
pub fn (v Value) str() string {
	return match v {
		i8 { v.str() }
		i16 { v.str() }
		i32 { v.str() }
		i64 { v.str() }
		int { v.str() }
		isize { v.str() }
		u8 { v.str() }
		u16 { v.str() }
		u32 { v.str() }
		u64 { v.str() }
		usize { v.str() }
		f32 { v.str() }
		f64 { v.str() }
		string { v.str() }
		bool { v.str() }
		[]Value { v.str() }
		map[string]Value { v.str() }
	}
}

// Field represents a named field of log record.
pub struct Field {
pub:
	name  string
	value Value
}

// as_map converts array of fields into map.
pub fn (f []Field) as_map() map[string]Value {
	mut mapping := map[string]Value{}
	for field in f {
		mapping[field.name] = field.value
	}
	return mapping
}

@[noinit]
pub struct Record {
	channel chan Record
pub:
	level  Level
	fields []Field
}

// append adds new fields to a record and returns the modified record.
pub fn (r Record) append(field ...Field) Record {
	if field.len == 0 {
		return r
	}
	mut fields_orig := unsafe { r.fields }
	fields_orig << field
	return Record{
		...r
		fields: &fields_orig
	}
}

// prepend adds new fields to the beginning of the record and returns the modified record.
pub fn (r Record) prepend(field ...Field) Record {
	if field.len == 0 {
		return r
	}
	mut new_fields := unsafe { field }
	new_fields << r.fields
	return Record{
		...r
		fields: new_fields
	}
}

// field adds new field with given name and value to a record and returns the modified record.
pub fn (r Record) field(name string, value Value) Record {
	return r.append(Field{ name: name, value: value })
}

// message adds new message field to a record and returns the modified record.
// This is a shothand for `field('message', 'message text')`.
pub fn (r Record) message(s string) Record {
	return r.field('message', s)
}

// error adds an error as new field to a record and returns the modified record.
// The IError .msg() and .code() methods output will be logged.
pub fn (r Record) error(err IError) Record {
	return r.append(Field{
		name:  'error'
		value: {
			'msg':  Value(err.msg())
			'code': Value(err.code())
		}
	})
}

// send sends a record to the record handler for the futher processing and writing.
pub fn (r Record) send() {
	r.channel <- r
}

pub struct Timestamp {
pub mut:
	// format sets the format of datetime in logs. TimestampFormat values
	// map 1-to-1 to the date formats provided by `time.Time`.
	// If .custom format is selected the `custom` field must be set.
	format TimestampFormat = .rfc3339

	// custom sets the custom datetime string format if format is set to .custom.
	// See docs for Time.format_custom() fn from stadnard `time` module.
	custom string

	// If local is true the local time will be used instead of UTC.
	local bool
}

fn (t Timestamp) as_value() Value {
	return timestamp(t.format, t.custom, t.local)
}

pub enum TimestampFormat {
	default
	rfc3339
	rfc3339_micro
	rfc3339_nano
	ss
	ss_micro
	ss_milli
	ss_nano
	unix
	unix_micro
	unix_milli
	unix_nano
	custom
}

@[params]
pub struct LogConfig {
pub:
	// level holds a logging level for the logger.
	// This value cannot be changed after logger initialization.
	level Level = .info

	// timestamp holds the timestamp settings.
	timestamp Timestamp

	add_level     bool = true // if true add `level` field to all log records.
	add_timestamp bool = true // if true add `timestamp` field to all log records.

	// handler holds a log record handler object which is used to process logs.
	handler RecordHandler = TextHandler{
		writer: os.stdout()
	}
}

fn timestamp(format TimestampFormat, custom string, local bool) Value {
	mut t := time.utc()
	if local {
		t = t.local()
	}
	return match format {
		.default { t.format() }
		.rfc3339 { t.format_rfc3339() }
		.rfc3339_micro { t.format_rfc3339_micro() }
		.rfc3339_nano { t.format_rfc3339_nano() }
		.ss { t.format_ss() }
		.ss_micro { t.format_ss_micro() }
		.ss_milli { t.format_ss_milli() }
		.ss_nano { t.format_ss_nano() }
		.unix { t.unix() }
		.unix_micro { t.unix_micro() }
		.unix_milli { t.unix_milli() }
		.unix_nano { t.unix_nano() }
		.custom { t.custom_format(custom) }
	}
}

// new creates new logger with given config. See LogConfig for defaults.
// This function starts a separate thread for processing and writing logs.
// The calling code MUST wait for this thread to complete to ensure all logs
// are written correctly. To do this, close the logger as shown in the examples.
// Example:
// ```v ignore
// log := structlog.new()
// defer {
// 	log.close()
// }
// ```
pub fn new(config LogConfig) StructuredLog {
	ch := chan Record{cap: 4096}

	mut logger := StructuredLog{
		LogConfig: config
		channel:   ch
	}

	handler_thread := go fn [mut logger] () {
		loop: for {
			mut rec := <-logger.channel or { break }

			if int(rec.level) > int(logger.level) {
				continue loop
			}

			mut extra_fields := []Field{}

			if logger.add_timestamp {
				extra_fields << Field{
					name:  'timestamp'
					value: logger.timestamp.as_value()
				}
			}

			if logger.add_level {
				extra_fields << Field{
					name:  'level'
					value: rec.level.str()
				}
			}

			rec = rec.prepend(...extra_fields)

			mut handler := logger.handler
			handler.handle(rec) or { eprintln('error when handling log record!') }

			if rec.level == .fatal {
				exit(1)
			}
		}
	}()

	logger.handler_thread = handler_thread

	return logger
}

@[heap; noinit]
pub struct StructuredLog {
	LogConfig
mut:
	channel        chan Record
	handler_thread thread
}

fn (s StructuredLog) record(level Level) Record {
	return Record{
		channel: s.channel
		level:   level
	}
}

// trace creates new log record with trace level.
pub fn (s StructuredLog) trace() Record {
	return s.record(.trace)
}

// debug creates new log record with debug level.
pub fn (s StructuredLog) debug() Record {
	return s.record(.debug)
}

// info creates new log record with info level.
pub fn (s StructuredLog) info() Record {
	return s.record(.info)
}

// warn creates new log record wth warning level.
pub fn (s StructuredLog) warn() Record {
	return s.record(.warn)
}

// error creates new log record with error level.
pub fn (s StructuredLog) error() Record {
	return s.record(.error)
}

// fatal creates new log record with fatal level.
// Note: After calling `send()` on record with fatal level the program will
// immediately exit with exit code 1.
pub fn (s StructuredLog) fatal() Record {
	return s.record(.fatal)
}

// close closes the internal communication channell (which is used for transfer
// log messages) and waits for record handler thread. It MUST be called for
// normal log processing.
pub fn (s StructuredLog) close() {
	s.channel.close()
	s.handler_thread.wait()
}

// DefaultHandler is a default empty implementation of RecordHandler interface.
// Its only purpose for existence is to be embedded in a concrete implementation
// of the interface for common struct fields.
pub struct DefaultHandler {
pub mut:
	writer io.Writer
}

// handle is the default implementation of handle method of RecordHandler. It does nothing.
pub fn (mut h DefaultHandler) handle(rec Record) ! {}

pub struct JSONHandler {
	DefaultHandler
}

// handle converts the log record into json string and writes it into underlying writer.
pub fn (mut h JSONHandler) handle(rec Record) ! {
	str := json.encode[map[string]Value](rec.fields.as_map()) + '\n'
	h.writer.write(str.bytes())!
}

pub struct TextHandler {
	DefaultHandler
pub:
	// If true use colors in log messages. Otherwise disable colors at all.
	// Turning on/off color here does not affect any colors that may be contained
	// within the log itself i.e. in-string ANSI escape sequences are not processed.
	color bool = true
}

// handle builds a log string from given record and writes it into underlying writer.
pub fn (mut h TextHandler) handle(rec Record) ! {
	mut buf := strings.new_builder(512)
	for i, field in rec.fields {
		match field.name {
			'timestamp' {
				if field.value is string {
					buf.write_string(field.value)
				} else {
					buf.write_string((field.value as i64).str())
				}
			}
			'level' {
				mut lvl := ''
				if h.color {
					lvl = match rec.level {
						.trace { term.magenta('TRACE') }
						.debug { term.cyan('DEBUG') }
						.info { term.white('INFO ') }
						.warn { term.yellow('WARN ') }
						.error { term.red('ERROR') }
						.fatal { term.bg_red('FATAL') }
						.none { '' }
					}
				} else {
					lvl = match rec.level {
						.trace { 'TRACE' }
						.debug { 'DEBUG' }
						.info { 'INFO ' }
						.warn { 'WARN ' }
						.error { 'ERROR' }
						.fatal { 'FATAL' }
						.none { '' }
					}
				}
				buf.write_byte(`[`)
				buf.write_string(lvl)
				buf.write_byte(`]`)
			}
			else {
				if field.value is map[string]Value {
					mut j := 0
					for k, v in field.value {
						j++
						buf.write_string('${field.name}.${k}')
						buf.write_byte(`:`)
						buf.write_byte(` `)
						buf.write_string(quote(v.str()))
						if j != field.value.len {
							buf.write_byte(` `)
						}
					}
				} else {
					buf.write_string(field.name)
					buf.write_byte(`:`)
					buf.write_byte(` `)
					buf.write_string(quote(field.value.str()))
				}
			}
		}
		if i != rec.fields.len {
			buf.write_byte(` `)
		}
	}
	buf.write_byte(`\n`)
	h.writer.write(buf)!
}

@[inline]
fn quote(input string) string {
	if !input.contains(' ') {
		return input
	}
	if input.contains("'") {
		return '"' + input + '"'
	}
	return "'" + input + "'"
}
