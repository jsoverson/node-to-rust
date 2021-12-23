use std::{fs, path::PathBuf};

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

    /// The path to the JSON data to use as input.
    #[structopt(parse(from_os_str))]
    pub(crate) json_path: PathBuf,
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

fn run(options: CliOptions) -> anyhow::Result<serde_json::Value> {
    let module = Module::from_file(&options.file_path)?;
    info!("Module loaded");

    let json = fs::read_to_string(options.json_path)?;
    let data: serde_json::Value = serde_json::from_str(&json)?;
    debug!("Data: {:?}", data);

    let bytes = rmp_serde::to_vec(&data)?;

    debug!("Running  {} with payload: {:?}", options.operation, bytes);
    let result = module.run(&options.operation, &bytes)?;
    let unpacked: serde_json::Value = rmp_serde::from_read_ref(&result)?;

    Ok(unpacked)
}
