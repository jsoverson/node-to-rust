mod generated;
pub use generated::*;
use wapc_guest::prelude::*;

#[no_mangle]
pub fn wapc_init() {
    Handlers::register_hello(hello);
}

fn hello(name: String) -> HandlerResult<String> {
    Ok(format!("Hello, {}.", name))
}
