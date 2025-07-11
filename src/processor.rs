use crate::sourcemap_handler::deobfuscate_file_optimized;
use anyhow::Result;
use colored::*;
use futures::future::join_all;
use indicatif::{ProgressBar, ProgressStyle};
use tokio::fs;
use walkdir::WalkDir;

pub async fn process_folder(input_dir: &str, output_dir: &str) -> Result<()> {
    fs::create_dir_all(output_dir).await?;

    let mut jobs = Vec::new();

    for entry in WalkDir::new(input_dir).into_iter().filter_map(Result::ok) {
        let path = entry.path().to_path_buf();
        if path.extension().map(|ext| ext == "js").unwrap_or(false) {
            let map_path = path.with_extension("js.map");
            if map_path.exists() {
                jobs.push((path, map_path));
            }
        }
    }

    let pb = ProgressBar::new(jobs.len() as u64);
    pb.set_style(
        ProgressStyle::with_template("[{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len} {msg}")?
            .progress_chars("##-"),
    );

    let tasks: Vec<_> = jobs
        .into_iter()
        .map(|(js_path, map_path)| {
            let pb = pb.clone();
            let output_dir = output_dir.to_string();
            tokio::spawn(async move {
                match deobfuscate_file_optimized(&js_path, &map_path, &output_dir).await {
                    Ok(_) => {
                        pb.inc(1);
                        Ok(())
                    }
                    Err(e) => {
                        eprintln!("{} {js_path:?}: {e}", "[error]".red());
                        pb.inc(1);
                        Err(e)
                    }
                }
            })
        })
        .collect();

    let results = join_all(tasks).await;
    pb.finish_with_message("Done");

    for res in results {
        res??;
    }

    Ok(())
}
