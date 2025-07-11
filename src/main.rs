mod cli;
mod processor;
mod sourcemap_handler;

use anyhow::Result;
use clap::Parser;
use cli::Cli;
use processor::process_folder;

#[tokio::main(flavor = "multi_thread")]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    process_folder(&cli.input_dir, &cli.output_dir).await?;
    Ok(())
}

