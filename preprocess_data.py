import os
import logging
import cv2
import numpy as np
from pymongo import MongoClient

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("arabic_api")
logger.setLevel(logging.INFO)

# MongoDB connection
client = MongoClient("mongodb://localhost:27017")
db = client["handwriting_database"]
collection = db["labeled_data"]

# Arabic letters for labeling
arabic_letters = [
    "ا", "ب", "ت", "ث", "ج", "ح", "خ", "د", "ذ", "ر", "ز", "س", "ش", "ص", "ض", 
    "ط", "ظ", "ع", "غ", "ف", "ق", "ك", "ل", "م", "ن", "ه", "و", "ي"
]

def preprocess_image(image_path):
    """
    Preprocess image: resize, grayscale, normalize, and flatten.
    Returns a 1D numpy array of pixel features.
    """
    try:
        image = cv2.imread(image_path)
        if image is None:
            raise ValueError(f"Image not found or unreadable: {image_path}")
        
        # Resize to 32 x 32
        image = cv2.resize(image, (32, 32), interpolation=cv2.INTER_AREA)
        # Convert to grayscale
        img = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        # Normalize pixel values to range [0, 1]
        img = img.astype(np.float32) / 255.0
        # Flatten to 1D array
        return img.flatten()
    except Exception as e:
        logger.error(f"Error preprocessing image {image_path}: {e}")
        return None

def extract_label_from_filename(filename):
    """
    Extract the Arabic letter label from the filename.
    Supports multiple naming patterns.
    """
    try:
        if "tutorial_letter" in filename:
            # Extract the index from tutorial_letter_X.png
            letter_index = int(filename.split("_")[2].split(".")[0])
            return arabic_letters[letter_index]
        elif "_label_" in filename:
            # Extract the label index from _label_X.png
            label_index = int(filename.split("_label_")[1].split(".")[0])
            return arabic_letters[label_index - 1]
        else:
            raise ValueError(f"Unknown filename pattern: {filename}")
    except Exception as e:
        logger.error(f"Error extracting label from filename {filename}: {e}")
        return None

def load_and_store_data(data_path, dsid, weight=1):
    """
    Load images from the given path, preprocess, and store them in MongoDB.
    """
    # Check if the data path exists
    if not os.path.exists(data_path):
        logger.error(f"Data path does not exist: {data_path}")
        return

    logger.info(f"Starting data processing from {data_path} for DSID {dsid}...")
    total_files = len([f for f in os.listdir(data_path) if f.endswith(".png")])
    inserted_count = 0

    # Iterate through all files in the directory
    for idx, img_file in enumerate(os.listdir(data_path)):
        if not img_file.endswith(".png"):
            continue  # Skip non-image files

        img_path = os.path.join(data_path, img_file)

        # Preprocess the image
        try:
            features = preprocess_image(img_path)
            if features is None:
                logger.warning(f"Skipping invalid or unreadable image: {img_file}")
                continue
        except Exception as e:
            logger.error(f"Error preprocessing image {img_file}: {e}")
            continue

        # Extract the label from the filename
        try:
            label = extract_label_from_filename(img_file)
            if label is None:
                logger.warning(f"Skipping file with unknown or invalid label: {img_file}")
                continue
        except Exception as e:
            logger.error(f"Error extracting label from {img_file}: {e}")
            continue

        # Prepare records for insertion with weight
        try:
            records = [{"feature": features.tolist(), "label": label, "dsid": dsid} for _ in range(weight)]
            collection.insert_many(records)
            inserted_count += len(records)
        except Exception as e:
            logger.error(f"Error inserting records for {img_file}: {e}")
            continue

        # Log progress every 100 files or at the end
        if (idx + 1) % 100 == 0 or idx + 1 == total_files:
            logger.info(f"Processed {idx + 1}/{total_files} files...")

    # Final log message
    if inserted_count == 0:
        logger.warning(f"No records were inserted for DSID {dsid}. Check data and processing.")
    else:
        logger.info(f"Data processing complete. Total records inserted: {inserted_count}")


