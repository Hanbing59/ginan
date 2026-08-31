#pragma once
struct Receiver;

/**
 * @brief Preprocess GNSS observations
 * @param trace Trace object for logging
 * @param rec Receiver object containing observations to preprocess
 * @param realEpoch Flag indicating if this is a real epoch (true) or a simulated epoch (false)
 * @param kfState_ptr Optional pointer to filter to take ephemerides from
 * @param remote_ptr Optional pointer to filter to take ephemerides from
 */
void preprocessor(
    Trace&    trace,
    Receiver& rec,
    bool      realEpoch   = false,
    KFState*  kfState_ptr = nullptr,
    KFState*  remote_ptr  = nullptr
);
void obsVariances(ObsList& obsList);
void cleanSignals(ObsList& obsList);