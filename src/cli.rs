use clap::Parser;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
pub struct Cli {
    /// Input directory containing .js and .map files
    #[arg(short, long)]
    pub input_dir: String,

    /// Output directory for deobfuscated files
    #[arg(short, long)]
    pub output_dir: String,
}
