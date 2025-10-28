package com.example.dbexample.config;

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
public class DataSourceAspect {

    @Pointcut("@annotation(org.springframework.transaction.annotation.Transactional)")
    public void transactionalMethods() {
    }

    @Around("transactionalMethods()")
    public Object setReadOnlyDataSource(ProceedingJoinPoint joinPoint) throws Throwable {
        MethodSignature signature = (MethodSignature) joinPoint.getSignature();
        Method method = signature.getMethod();
        Transactional transactional = method.getAnnotation(Transactional.class);

        try {
            if (transactional != null && transactional.readOnly()) {
                ReplicationContextHolder.setReplicationType("READ");
            } else {
                ReplicationContextHolder.setReplicationType("WRITE");
            }
            return joinPoint.proceed();
        } finally {
            ReplicationContextHolder.clearContext();
        }
    }
}

