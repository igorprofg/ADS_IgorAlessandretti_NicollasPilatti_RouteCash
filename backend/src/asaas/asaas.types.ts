export interface AsaasCustomer {
  id: string;
  name: string;
  cpfCnpj?: string;
  email?: string;
  mobilePhone?: string;
  externalReference?: string;
  deleted?: boolean;
}

export interface AsaasListResponse<T> {
  object: 'list';
  hasMore: boolean;
  totalCount: number;
  limit: number;
  offset: number;
  data: T[];
}

export interface AsaasCheckout {
  id: string;
  link?: string;
  status?: 'ACTIVE' | 'PAID' | 'CANCELED' | 'EXPIRED';
}

export type AsaasSubscriptionCycle =
  | 'WEEKLY'
  | 'BIWEEKLY'
  | 'MONTHLY'
  | 'BIMONTHLY'
  | 'QUARTERLY'
  | 'SEMIANNUALLY'
  | 'YEARLY';