package net.mgrid.tranzoom.rabbitmq

import org.springframework.transaction.support.TransactionSynchronization
import org.aopalliance.intercept.MethodInvocation
import org.springframework.transaction.support.TransactionSynchronizationManager
import scala.beans.BeanProperty
import org.aopalliance.intercept.MethodInterceptor
import org.springframework.beans.factory.annotation.Required
import org.slf4j.LoggerFactory

class SynchronizationActivatingInterceptor extends MethodInterceptor {

  private val logger = LoggerFactory.getLogger(classOf[SynchronizationActivatingInterceptor])

  @BeanProperty @Required
  var transactionSynchronization: TransactionSynchronization = _

  override def invoke(invocation: MethodInvocation): Object = {
    if (TransactionSynchronizationManager.isSynchronizationActive()) {
      
      if (logger.isDebugEnabled()) {
        val t = Thread.currentThread().getName()
        val synchronizations = TransactionSynchronizationManager.getSynchronizations()
        logger.debug(s"Register transaction synchronization $transactionSynchronization for thread $t (${synchronizations.size()} active)")
      }
      
      TransactionSynchronizationManager.registerSynchronization(transactionSynchronization)
    }
    
    invocation.proceed()
  }
}
