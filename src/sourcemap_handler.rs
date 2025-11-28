use anyhow::Result;
use sourcemap::SourceMap;
use std::{
    collections::HashMap,
    path::{Component, Path, PathBuf},
};
use tokio::fs;

pub async fn deobfuscate_file_optimized(map_path: &Path, output_path: &str) -> Result<()> {
    let map_data = fs::read(map_path).await?;
    let sm = SourceMap::from_slice(&map_data)?;

    let mut processed_files: HashMap<String, String> = HashMap::new();

    for source_id in 0..sm.get_source_count() {
        if let Some(source_name) = sm.get_source(source_id)
            && let Some(source_content) = sm.get_source_contents(source_id)
        {
            processed_files.insert(source_name.to_string(), source_content.to_string());
        }
    }

    for (file_name, content) in processed_files {
        let mut file_path = PathBuf::from(output_path);
        let file_name = flat_filename_deep(&file_name);
        file_path.push(&file_name);

        if let Some(parent) = file_path.parent() {
            fs::create_dir_all(parent).await?;
        }

        match fs::write(&file_path, content).await {
            Ok(()) => {}
            Err(e) => eprintln!("Failed to write file {}: {}", file_path.display(), e),
        }
    }

    Ok(())
}

fn flat_filename_deep(path: &str) -> String {
    let mut result = PathBuf::new();

    for component in Path::new(path).components() {
        match component {
            Component::ParentDir => {}
            Component::Normal(c) => result.push(c),
            _ => {}
        }
    }

    result.to_string_lossy().to_string()
}
