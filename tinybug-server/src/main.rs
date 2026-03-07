use axum::{Json, Router, extract::State, http::StatusCode, routing::post};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::Mutex;
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use tracing::info;
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Device {
    pub name: String,
    pub model: String,
    #[serde(rename = "systemName")]
    pub system_name: String,
    #[serde(rename = "systemVersion")]
    pub system_version: String,
    #[serde(rename = "batteryLevel")]
    pub battery_level: f32,
    #[serde(rename = "batteryState")]
    pub battery_state: i32,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct Location {
    pub latitude: f64,
    pub longitude: f64,
    pub altitude: f64,
    #[serde(rename = "horizontalAccuracy")]
    pub horizontal_accuracy: f64,
    #[serde(rename = "verticalAccuracy")]
    pub vertical_accuracy: f64,
    pub speed: f64,
    pub course: f64,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct TelemetryPayload {
    pub timestamp: String,
    pub location: Location,
    pub device: Device,
}

#[derive(Debug, Serialize, Clone)]
pub struct TelemetryRecord {
    pub id: Uuid,
    pub received_at: DateTime<Utc>,
    #[serde(flatten)]
    pub payload: TelemetryPayload,
}
type Store = Arc<Mutex<Vec<TelemetryRecord>>>;

#[derive(Serialize)]
pub struct IngestResponse {
    pub status: &'static str,
    pub id: Uuid,
    pub received_at: DateTime<Utc>,
}

#[derive(Serialize)]
pub struct ErrorResponse {
    pub status: &'static str,
    pub message: String,
}

fn validate_location(loc: &Location) -> Result<(), String> {
    if !(-90.0..=90.0).contains(&loc.latitude) {
        return Err(format!(
            "latitude {} is out of range [-90, 90]",
            loc.latitude
        ));
    }

    if !(-180.0..=180.0).contains(&loc.latitude) {
        return Err(format!(
            "longitude {} is out of range [-180, 180]",
            loc.longitude
        ));
    }

    Ok(())
}

#[axum::debug_handler]
async fn ingest_handler(
    State(store): State<Store>,
    Json(payload): Json<TelemetryPayload>,
) -> Result<(StatusCode, Json<IngestResponse>), (StatusCode, Json<ErrorResponse>)> {
    validate_location(&payload.location).map_err(|msg| {
        (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(ErrorResponse {
                status: "error",
                message: msg,
            }),
        )
    })?;

    let record = TelemetryRecord {
        id: Uuid::new_v4(),
        received_at: Utc::now(),
        payload,
    };

    let response = IngestResponse {
        status: "ok",
        id: record.id,
        received_at: record.received_at,
    };

    info!(
        id = %record.id,
        device = %record.payload.device.name,
        model = %record.payload.device.model,
        lat = record.payload.location.latitude,
        lon = record.payload.location.longitude,
        battery = record.payload.device.battery_level,
        "telemetry ingested"
    );

    store.lock().await.push(record);

    Ok((StatusCode::CREATED, Json(response)))
}

pub fn build_router(store: Store) -> Router {
    Router::new()
        .route("/ingest", post(ingest_handler))
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(store)
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "telemetry_ingest=debug,tower_http=info".into()),
        )
        .init();

    let store: Store = Arc::new(Mutex::new(Vec::new()));
    let app = build_router(store);

    let addr = "0.0.0.0:8069";
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("failed to bind address");
    info!("listening on http://{}", addr);
    axum::serve(listener, app).await.expect("server error");
}
