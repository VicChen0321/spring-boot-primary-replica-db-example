package com.example.dbexample.config;

public class ReplicationContextHolder {

    private static final ThreadLocal<String> contextHolder = new ThreadLocal<>();

    public static void setReplicationType(String replicationType) {
        contextHolder.set(replicationType);
    }

    public static String getContext() {
        return contextHolder.get();
    }

    public static void clearContext() {
        contextHolder.remove();
    }
}

