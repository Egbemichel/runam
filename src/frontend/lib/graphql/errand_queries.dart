// File: lib/graphql/errand_queries.dart

const String errandStatusQuery = r'''
  query GetErrandStatus($id: ID!) {
  errandStatus(errandId: $id) {
    status
    isOpen
    runner {
      name
      latitude
      longitude
    }
    nearbyRunners {
      id
      latitude
      longitude
      distanceM
    }
  }
}
''';

const String runnerPendingOffersQuery = r'''
  query RunnerPendingOffers {
    myPendingOffers {
      id
      errandId
      price
      expiresAt
      expiresIn
      
      errand {
        id
        type
        speed
        
        goTo {
          latitude
          longitude
          address
        }
        
        tasks {
          description
          price
        }
      }
    }
  }
''';

const String acceptOfferMutation = r'''
  mutation AcceptOffer($offerId: ID!) {
    acceptErrandOffer(offerId: $offerId) {
      ok
    }
  }
''';

const String rejectOfferMutation = r'''
  mutation RejectOffer($offerId: ID!) {
    rejectErrandOffer(offerId: $offerId) {
      ok
    }
  }
''';
