package com.example.dbexample.config;

import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Pointcut;
import org.aspectj.lang.reflect.MethodSignature;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.lang.reflect.Method;

@Aspect
@Component
@Slf4j
public class DataSourceAspect {

    @Pointcut("@annotation(org.springframework.transaction.annotation.Transactional)")
    public void transactionalMethods() {
    }

    @Around("transactionalMethods()")
    public Object setReadOnlyDataSource(ProceedingJoinPoint joinPoint) throws Throwable {
        MethodSignature signature = (MethodSignature) joinPoint.getSignature();
        Method method = signature.getMethod();
        Transactional transactional = method.getAnnotation(Transactional.class);

        String methodName = joinPoint.getSignature().toShortString();
        
        try {
            if (transactional != null && transactional.readOnly()) {
                log.debug("📖 AOP 檢測到讀操作: {}", methodName);
                ReplicationContextHolder.setReplicationType("READ");
            } else {
                log.debug("📝 AOP 檢測到寫操作: {}", methodName);
                ReplicationContextHolder.setReplicationType("WRITE");
            }
            return joinPoint.proceed();
        } finally {
            ReplicationContextHolder.clearContext();
        }
    }
}

