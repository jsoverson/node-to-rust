use thiserror::Error;

#[derive(Error, Debug)]
pub enum Error {
    #[error("Error {0}")]
    Msg(String),
    #[error(transparent)]
    IOError(#[from] std::io::Error),
}
