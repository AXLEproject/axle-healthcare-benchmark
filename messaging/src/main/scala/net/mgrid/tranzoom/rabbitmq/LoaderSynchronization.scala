package net.mgrid.tranzoom.rabbitmq

import org.springframework.transaction.support.TransactionSynchronizationAdapter
import org.springframework.integration.store.MessageGroupStore
import org.springframework.beans.factory.annotation.Required
import scala.beans.BeanProperty

class LoaderSynchronization extends TransactionSynchronizationAdapter {
  
  @BeanProperty @Required
  var messageStore: MessageGroupStore = _
  
  /*
   * Make sure we expire all message groups in the thread bound to the transaction
   */
  override def beforeCommit(readOnly: Boolean): Unit = {
    messageStore.expireMessageGroups(0)
  }

}