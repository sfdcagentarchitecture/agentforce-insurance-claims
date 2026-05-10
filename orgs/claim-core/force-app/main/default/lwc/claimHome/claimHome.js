import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class ClaimHome extends NavigationMixin(LightningElement) {

    navigateToSubmitClaim() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'submit-claim'
            }
        });
    }

    navigateToMyClaims() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'my-claims'
            }
        });
    }
}