import os
import motor.motor_asyncio
from fastapi import FastAPI, HTTPException, File, UploadFile
from sklearn.preprocessing import LabelEncoder
from joblib import dump, load
from xgboost import XGBClassifier
import numpy as np
import logging
from preprocess_data import load_and_store_data


# Configure logging
logging.basicConfig(level=logging.INFO)  # Set to INFO to avoid excessive debug logs
logger = logging.getLogger("arabic_api")

# For pymongo logging, reduce verbosity to WARNING
logging.getLogger('pymongo').setLevel(logging.WARNING)

# MongoDB Connection Settings
MONGO_DETAILS = "mongodb://localhost:27017"
client = motor.motor_asyncio.AsyncIOMotorClient(MONGO_DETAILS)
database = client.handwriting_database
collection = database.labeled_data

# FastAPI App Initialization
app = FastAPI()

# Directory for storing uploaded PNG files
UPLOAD_DIR = "/Users/zareenahmurad/Desktop/CS/CS5323/Lab5Python/datasets/userdata" 
os.makedirs(UPLOAD_DIR, exist_ok=True)  # Ensure the directory exists

# Arabic letters for labeling
arabic_letters = [
    "ا", "ب", "ت", "ث", "ج", "ح", "خ", "د", "ذ", "ر", "ز", "س", "ش", "ص", "ض", 
    "ط", "ظ", "ع", "غ", "ف", "ق", "ك", "ل", "م", "ن", "ه", "و", "ي"
]

# API Endpoints
@app.get("/")
async def root():
    return {"message": "Arabic Handwriting Recognition API is running"}


@app.get("/train_model/{dsid}")
async def train_model(dsid: int):
    try:
        logger.info(f"Training started for DSID: {dsid}")

        # Fetch original and user-provided data from MongoDB
        original_data = await collection.find({"dsid": 0}).to_list(length=None)  # Original dataset
        user_data = await collection.find({"dsid": dsid}).to_list(length=None)   # User-provided data
        
        if not original_data and not user_data:
            raise HTTPException(status_code=404, detail="No datapoints found")
        
        # Combine original data with user data
        datapoints = original_data + user_data
        logger.info(f"Original data size: {len(original_data)}, User data size: {len(user_data)}")
        logger.info(f"Combined dataset size: {len(datapoints)}")

        # Prepare features and labels
        features = np.array([np.array(dp["feature"]) for dp in datapoints], dtype=np.float32) / 255.0
        labels = np.array([dp["label"] for dp in datapoints])
        
        # Encode labels during training
        label_encoder = LabelEncoder()
        labels = label_encoder.fit_transform(labels)

        logger.info(f"Features shape: {features.shape}, Labels shape: {labels.shape}")

        # Save label encoder for use during testing
        label_encoder_path = f"models/label_encoder_dsid_{dsid}.joblib"
        dump(label_encoder, label_encoder_path)
        logger.info(f"Label encoder saved at {label_encoder_path}")

        # Load existing model (if available) or initialize a new one
        model_path = f"models/model_dsid_{dsid}_XGBoost.joblib"
        if os.path.exists(model_path):
            model = load(model_path)
            logger.info(f"Loaded existing model from {model_path}")
        else:
            model = XGBClassifier(eval_metric="mlogloss", n_estimators=300)
            logger.info("Initialized new XGBoost model")

        logger.info("Training model...")
        
        # Train the model
        model.fit(features, labels)
        logger.info("XGBoost model training completed successfully")

        # Save the model
        dump(model, model_path)
        logger.info(f"XGBoost model saved at {model_path}")
        
        return {"message": "XGBoost model trained successfully", "model_path": model_path}
    
    except Exception as e:
        logger.error(f"Error training model for DSID {dsid}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/prepare_dataset/")
async def prepare_dataset(data: dict):
    try:
        logger.info("Preparing dataset...")
        dsid = data.get("dsid")
        data_path = data.get("data_path")  # Ensure this key matches the Swift payload

        if not dsid or not data_path:
            raise ValueError("Missing required parameters: 'dsid' and/or 'data_path'")

        if not os.path.exists(data_path):
            raise FileNotFoundError(f"Dataset path not found: {data_path}")

        logger.info(f"Starting preprocessing for dataset DSID {dsid}...")
        load_and_store_data(data_path, dsid)

        logger.info(f"Dataset for DSID {dsid} processed and stored successfully.")
        return {"message": f"Dataset prepared for DSID {dsid}"}

    except Exception as e:
        logger.error(f"Error in /prepare_dataset/: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/upload_png/")
async def upload_png(file: UploadFile = File(...)):
    """
    Endpoint to upload a single PNG file and save it to the local directory.
    """
    try:
        file_path = os.path.join(UPLOAD_DIR, file.filename)
        with open(file_path, "wb") as f:
            f.write(await file.read())
        logger.info(f"File {file.filename} uploaded successfully to {UPLOAD_DIR}.")
        return {"message": f"File {file.filename} uploaded successfully."}
    except Exception as e:
        logger.error(f"Failed to upload PNG file: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to upload file: {str(e)}")


@app.post("/prepare_user_data/")
async def prepare_user_data(data: dict):
    """
    Endpoint to preprocess and store user-submitted tutorial data.
    """
    try:
        logger.info("Preparing user data...")
        dsid = data.get("dsid")
        tutorial_data = data.get("tutorial_data")

        if not dsid or not tutorial_data:
            raise HTTPException(status_code=400, detail="Missing required parameters: 'dsid' and/or 'tutorial_data'.")

        records = [
            {"feature": item["feature"], "label": item["label"], "dsid": dsid}
            for item in tutorial_data
        ]

        # Insert the tutorial data into MongoDB
        result = await collection.insert_many(records)
        logger.info(f"Inserted {len(result.inserted_ids)} user tutorial records for DSID {dsid}.")

        return {"message": f"User data for DSID {dsid} processed and stored successfully."}
    except Exception as e:
        logger.error(f"Error in /prepare_user_data/: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/predict/")
async def predict(data: dict):
    """
    Predict the label for a given feature vector.
    """
    try:
        dsid = data.get("dsid")
        feature = data.get("feature")

        if dsid is None or feature is None:
            raise HTTPException(status_code=400, detail="Missing required parameters: 'dsid' and/or 'feature'.")

        # Load the model
        model_path = f"models/model_dsid_{dsid}_XGBoost.joblib"

        if not os.path.exists(model_path):
            raise HTTPException(status_code=404, detail="Model file not found.")

        model = load(model_path)

        # Load the label encoder
        label_encoder_path = f"models/label_encoder_dsid_{dsid}.joblib"
        if not os.path.exists(label_encoder_path):
            raise HTTPException(status_code=404, detail="Label encoder file not found.")

        label_encoder = load(label_encoder_path)

        # Normalize the feature vector to [0, 1]
        normalized_feature = np.array(feature) / 255.0

        # Make prediction
        prediction = model.predict([normalized_feature])[0]
        logger.info(f"Predicted class index: {prediction}")

        # Map the numeric prediction to the corresponding label
        if prediction < 0 or prediction >= len(label_encoder.classes_):
            raise HTTPException(status_code=400, detail="Prediction index out of range.")

        predicted_label = label_encoder.inverse_transform([prediction])[0]
        logger.info(f"Predicted label: {predicted_label}")

        logger.info(f"Predicted class index: {int(prediction)}, Mapped label: {predicted_label}")

        return {"prediction": int(prediction)}
    except Exception as e:
        logger.error(f"Error during prediction: {e}")
        raise HTTPException(status_code=500, detail=str(e))




@app.delete("/clear_database/")
async def clear_database():
    try:
        await collection.delete_many({})
        logger.info("Database cleared successfully.")
        return {"message": "Database cleared successfully."}
    except Exception as e:
        logger.error(f"Error clearing database: {e}")
        raise HTTPException(status_code=500, detail=str(e))
