# Structured Logs

The `structlog` module develops the idea of [vlogger](https://github.com/CG-SS/vlogger)
by constructing a record using a chain of method calls.

## Concept

When initialized, the logger starts a thread with a record handler. The logger
has a number of methods, each of which creates a record with the corresponding
logging level, e.g. `info()`.

By chaining method calls, the module user can create a record with any structure.
The final `.send()` call sends the record to the handler for writing.

The record handler completely defines how to prepare the `Record` object for
writing, how and whereto the writing will occur. The handler must implement the
`RecordHandler` interface. Two ready-made handlers for recording are provided:
`TextHandler` (the default) and `JSONHandler` for JSON formatted logs.

## Usage

```v
import structlog

fn main() {
	log := structlog.new()
	defer {
		log.close()
	}

	log.info().message('Hello, World!').send()
}
```

Output:

```
2026-01-03T09:33:35.366Z [INFO ] message: 'Hello, World!'
```

See also [examples](examples/) dir for more usage examples.
