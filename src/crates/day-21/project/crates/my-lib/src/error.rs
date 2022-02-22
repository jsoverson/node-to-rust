use std::path::PathBuf;

#[derive(thiserror::Error, Debug)]
pub enum Error {
    #[error(transparent)]
    WapcError(#[from] wapc::errors::Error),
    #[error("Could not read file {0}: {1}")]
    FileNotReadable(PathBuf, String),
}
