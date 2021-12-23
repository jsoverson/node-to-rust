mod generated;
pub use generated::*;
use handlebars::Handlebars;
use wapc_guest::prelude::*;

#[no_mangle]
pub fn wapc_init() {
    Handlers::register_render(render);
}

fn render(blog: Blog, template: String) -> HandlerResult<String> {
    let mut handlebars = Handlebars::new();
    handlebars.register_template_string("blog", template)?;

    Ok(handlebars.render("blog", &blog)?)
}
