use my_lib::Module;

fn main() {
    match Module::from_file("./module.wasm") {
        Ok(_) => {
            println!("Module loaded");
        }
        Err(e) => {
            println!("Module failed to load: {}", e);
        }
    }
}
