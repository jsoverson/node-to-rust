use std::path::PathBuf;

use my_lib::Module;
use structopt::{clap::AppSettings, StructOpt};

#[macro_use]
extern crate log;

#[derive(StructOpt)]
#[structopt(
    name = "wasm-runner",
    about = "Sample project from https://vino.dev/blog/node-to-rust-day-1-rustup/",
    global_settings(&[
      AppSettings::ColoredHelp
    ]),
)]
struct CliOptions {
    /// The WebAssembly file to load.
    #[structopt(parse(from_os_str))]
    pub(crate) file_path: PathBuf,

    /// The operation to invoke in the WASM file.
    #[structopt()]
    pub(crate) operation: String,

    /// The data to pass to the operation
    #[structopt()]
    pub(crate) data: String,
}

fn main() {
    env_logger::init();
    debug!("Initialized logger");

    let options = CliOptions::from_args();

    match run(options) {
        Ok(output) => {
            println!("{}", output);
            info!("Done");
        }
        Err(e) => {
            error!("Module failed to load: {}", e);
            std::process::exit(1);
        }
    };
}

fn run(options: CliOptions) -> anyhow::Result<String> {
    let module = Module::from_file(&options.file_path)?;
    info!("Module loaded");

    let bytes = rmp_serde::to_vec(&options.data)?;
    let result = module.run(&options.operation, &bytes)?;
    let unpacked: String = rmp_serde::from_read_ref(&result)?;

    Ok(unpacked)
}
